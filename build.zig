const std = @import("std");
const Build = std.Build;

fn project_root(comptime path: []const u8) []const u8 {
    const root = std.fs.path.dirname(@src().file) orelse unreachable;
    return std.fmt.comptimePrint("{s}/{s}", .{ root, path });
}

fn define_from_bool(val: bool) ?u1 {
    return if (val) 1 else null;
}

pub fn build(b: *Build) void {
    const libusb_dep = b.dependency("libusb_c", .{});
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const system_libudev = b.option(bool, "system-libudev", "link with system libudev on linux") orelse true;
    const linkage = b.option(std.builtin.LinkMode, "linkage", "static vs dynamic linkage") orelse .dynamic;

    const libusb = create_libusb(b, libusb_dep.builder, target, optimize, linkage, system_libudev);
    b.installArtifact(libusb);

    const build_all = b.step("all", "build libusb for all targets");
    for (targets(b)) |t| {
        const lib = create_libusb(b, libusb_dep.builder, t, optimize, linkage, system_libudev);
        build_all.dependOn(&lib.step);
    }
}

fn create_libusb(
    b: *Build,
    libusb_b: *Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    system_libudev: bool,
) *Build.Step.Compile {
    const is_posix =
        target.result.os.tag == .macos or
        target.result.os.tag == .linux or
        target.result.os.tag == .openbsd;

    const lib = b.addLibrary(.{
        .name = "usb",
        .linkage = linkage,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    lib.root_module.addCSourceFiles(.{
        .root = libusb_b.path(""),
        .files = src,
    });

    if (is_posix)
        lib.root_module.addCSourceFiles(.{
            .root = libusb_b.path(""),
            .files = posix_platform_src,
        });

    if (target.result.os.tag == .macos) {
        lib.root_module.addCSourceFiles(.{
            .root = libusb_b.path(""),
            .files = darwin_src,
        });
        lib.root_module.linkFramework("CoreFoundation", .{});
        lib.root_module.linkFramework("IOKit", .{});
        lib.root_module.linkFramework("Security", .{});
    } else if (target.result.os.tag == .linux) {
        lib.root_module.addCSourceFiles(.{
            .root = libusb_b.path(""),
            .files = linux_src,
        });
        if (system_libudev) {
            lib.root_module.addCSourceFiles(.{
                .root = libusb_b.path(""),
                .files = linux_udev_src,
            });
            lib.root_module.linkSystemLibrary("udev", .{});
        }
    } else if (target.result.os.tag == .windows) {
        lib.root_module.addCSourceFiles(.{
            .root = libusb_b.path(""),
            .files = windows_src,
        });
        lib.root_module.addCSourceFiles(.{
            .root = libusb_b.path(""),
            .files = windows_platform_src,
        });
    } else if (target.result.os.tag == .netbsd) {
        lib.root_module.addCSourceFiles(.{
            .root = libusb_b.path(""),
            .files = netbsd_src,
        });
    } else if (target.result.os.tag == .openbsd) {
        lib.root_module.addCSourceFiles(.{
            .root = libusb_b.path(""),
            .files = openbsd_src,
        });
    } else if (target.result.os.tag == .haiku) {
        lib.root_module.addCSourceFiles(.{
            .root = libusb_b.path(""),
            .files = haiku_src,
        });
    } else unreachable;

    lib.root_module.addIncludePath(libusb_b.path("libusb"));
    lib.installHeader(libusb_b.path("libusb/libusb.h"), "libusb.h");

    // config header
    if (target.result.os.tag == .macos) {
        lib.root_module.addIncludePath(libusb_b.path("Xcode"));
    } else if (target.result.abi == .msvc) {
        lib.root_module.addIncludePath(libusb_b.path("msvc"));
    } else if (target.result.abi == .android) {
        lib.root_module.addIncludePath(libusb_b.path("android"));
    } else {
        const config_h = b.addConfigHeader(.{ .style = .{
            .autoconf_undef = b.path("config.h.in"),
        } }, .{
            .DEFAULT_VISIBILITY = .@"__attribute__ ((visibility (\"default\")))",
            .ENABLE_DEBUG_LOGGING = define_from_bool(optimize == .Debug),
            .ENABLE_LOGGING = 1,
            .HAVE_ASM_TYPES_H = null,
            .HAVE_CLOCK_GETTIME = define_from_bool(!(target.result.os.tag == .windows)),
            .HAVE_DECL_EFD_CLOEXEC = null,
            .HAVE_DECL_EFD_NONBLOCK = null,
            .HAVE_DECL_TFD_CLOEXEC = null,
            .HAVE_DECL_TFD_NONBLOCK = null,
            .HAVE_DLFCN_H = null,
            .HAVE_EVENTFD = null,
            .HAVE_INTTYPES_H = null,
            .HAVE_IOKIT_USB_IOUSBHOSTFAMILYDEFINITIONS_H = define_from_bool(target.result.os.tag == .macos),
            .HAVE_LIBUDEV = define_from_bool(system_libudev),
            .HAVE_NFDS_T = null,
            .HAVE_PIPE2 = null,
            .HAVE_PTHREAD_CONDATTR_SETCLOCK = null,
            .HAVE_PTHREAD_SETNAME_NP = null,
            .HAVE_PTHREAD_THREADID_NP = null,
            .HAVE_STDINT_H = 1,
            .HAVE_STDIO_H = 1,
            .HAVE_STDLIB_H = 1,
            .HAVE_STRINGS_H = 1,
            .HAVE_STRING_H = 1,
            .HAVE_STRUCT_TIMESPEC = 1,
            .HAVE_SYSLOG = define_from_bool(is_posix),
            .HAVE_SYS_STAT_H = 1,
            .HAVE_SYS_TIME_H = 1,
            .HAVE_SYS_TYPES_H = 1,
            .HAVE_TIMERFD = null,
            .HAVE_UNISTD_H = 1,
            .LT_OBJDIR = null,
            .PACKAGE = "libusb-1.0",
            .PACKAGE_BUGREPORT = "libusb-devel@lists.sourceforge.net",
            .PACKAGE_NAME = "libusb-1.0",
            .PACKAGE_STRING = "libusb-1.0 1.0.26",
            .PACKAGE_TARNAME = "libusb-1.0",
            .PACKAGE_URL = "http://libusb.info",
            .PACKAGE_VERSION = "1.0.26",
            .PLATFORM_POSIX = define_from_bool(is_posix),
            .PLATFORM_WINDOWS = define_from_bool(target.result.os.tag == .windows),
            .STDC_HEADERS = 1,
            .UMOCKDEV_HOTPLUG = null,
            .USE_SYSTEM_LOGGING_FACILITY = null,
            .VERSION = "1.0.26",
            ._GNU_SOURCE = 1,
            ._WIN32_WINNT = null,
            .@"inline" = null,
        });
        lib.root_module.addConfigHeader(config_h);
    }

    return lib;
}

const src = &.{
    "libusb/core.c",
    "libusb/descriptor.c",
    "libusb/hotplug.c",
    "libusb/io.c",
    "libusb/strerror.c",
    "libusb/sync.c",
};

const posix_platform_src: []const []const u8 = &.{
    "libusb/os/events_posix.c",
    "libusb/os/threads_posix.c",
};

const windows_platform_src: []const []const u8 = &.{
    "libusb/os/events_windows.c",
    "libusb/os/threads_windows.c",
};

const darwin_src: []const []const u8 = &.{
    "libusb/os/darwin_usb.c",
};

const haiku_src: []const []const u8 = &.{
    "libusb/os/haiku_pollfs.cpp",
    "libusb/os/haiku_usb_backend.cpp",
    "libusb/os/haiku_usb_raw.cpp",
};

const linux_src: []const []const u8 = &.{
    "libusb/os/linux_netlink.c",
    "libusb/os/linux_usbfs.c",
};
const linux_udev_src: []const []const u8 = &.{
    "libusb/os/linux_udev.c",
};

const netbsd_src: []const []const u8 = &.{
    "libusb/os/netbsd_usb.c",
};

const null_src: []const []const u8 = &.{
    "libusb/os/null_usb.c",
};

const openbsd_src: []const []const u8 = &.{
    "libusb/os/openbsd_usb.c",
};

// sunos isn't supported by zig
const sunos_src: []const []const u8 = &.{
    "libusb/os/sunos_usb.c",
};

const windows_src: []const []const u8 = &.{
    "libusb/os/events_windows.c",
    "libusb/os/threads_windows.c",
    "libusb/os/windows_common.c",
    "libusb/os/windows_usbdk.c",
    "libusb/os/windows_winusb.c",
};

pub fn targets(b: *Build) [16]std.Build.ResolvedTarget {
    return [_]std.Build.ResolvedTarget{
        // zig fmt: off
        b.resolveTargetQuery(.{}),
        b.resolveTargetQuery(.{ .os_tag = .linux,   .cpu_arch = .x86_64,    .abi = .musl        }),
        b.resolveTargetQuery(.{ .os_tag = .linux,   .cpu_arch = .x86_64,    .abi = .gnu         }),
        b.resolveTargetQuery(.{ .os_tag = .linux,   .cpu_arch = .aarch64,   .abi = .musl        }),
        b.resolveTargetQuery(.{ .os_tag = .linux,   .cpu_arch = .aarch64,   .abi = .gnu         }),
        b.resolveTargetQuery(.{ .os_tag = .linux,   .cpu_arch = .arm,       .abi = .musleabi    }),
        b.resolveTargetQuery(.{ .os_tag = .linux,   .cpu_arch = .arm,       .abi = .musleabihf  }),
        b.resolveTargetQuery(.{ .os_tag = .linux,   .cpu_arch = .arm,       .abi = .gnueabi     }),
        b.resolveTargetQuery(.{ .os_tag = .linux,   .cpu_arch = .arm,       .abi = .gnueabihf   }),
        b.resolveTargetQuery(.{ .os_tag = .macos,   .cpu_arch = .aarch64                        }),
        b.resolveTargetQuery(.{ .os_tag = .macos,   .cpu_arch = .x86_64                         }),
        b.resolveTargetQuery(.{ .os_tag = .windows, .cpu_arch = .aarch64                        }),
        b.resolveTargetQuery(.{ .os_tag = .windows, .cpu_arch = .x86_64                         }),
        b.resolveTargetQuery(.{ .os_tag = .netbsd,  .cpu_arch = .x86_64                         }),
        b.resolveTargetQuery(.{ .os_tag = .openbsd, .cpu_arch = .x86_64                         }),
        b.resolveTargetQuery(.{ .os_tag = .haiku,   .cpu_arch = .x86_64                         }),
        // zig fmt: on
    };
}
