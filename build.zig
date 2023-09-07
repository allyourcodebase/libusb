const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const libusb = b.addStaticLibrary(.{
        .name = "libusb",
        .target = target,
        .optimize = optimize,
        .link_libc = true, // TODO
    });

    const config = b.addConfigHeader(.{
        .style = .{ .autoconf = .{ .path = "config.h.in" } },
    }, .{
        .DEFAULT_VISIBILITY = .@"__attribute__ ((visibility (\"default\")))",
        .ENABLE_DEBUG_LOGGING = null,
        .ENABLE_LOGGING = null,
        .HAVE_ASM_TYPES_H = 1,
        .HAVE_DECL_EFD_CLOEXEC = 1,
        .HAVE_DECL_EFD_NONBLOCK = 1,
        .HAVE_DECL_TFD_CLOEXEC = 1,
        .HAVE_DECL_TFD_NONBLOCK = 1,
        .HAVE_INTTYPES_H = 1,
        .HAVE_NFDS_T = 1,
        .HAVE_PIPE2 = 1,
        .HAVE_STDINT_H = 1,
        .HAVE_STDIO_H = 1,
        .HAVE_STDLIB_H = 1,
        .HAVE_STRINGS_H = 1,
        .HAVE_STRING_H = 1,
        .HAVE_STRUCT_TIMESPEC = null,
        .HAVE_SYSLOG = null,
        .HAVE_SYS_STAT_H = 1,
        .HAVE_SYS_TIME_H = 1,
        .HAVE_SYS_TYPES_H = 1,
        .HAVE_TIMERFD = 1,
        .HAVE_UNISTD_H = 1,
        .LT_OBJDIR = ".libs/",
        .PACKAGE = "libusb-1.0",
        .PACKAGE_BUGREPORT = "libusb-devel@lists.sourceforge.net",
        .PACKAGE_NAME = "libusb-1.0",
        .PACKAGE_STRING = "libusb-1.0 1.0.26",
        .PACKAGE_TARNAME = "libusb-1.0",
        .PACKAGE_URL = "http://libusb.info",
        .PACKAGE_VERSION = "1.0.26",
        .PRINTF_FORMAT = null, // TODO
        .STDC_HEADERS = 1,
        .UMOCKDEV_HOTPLUG = null,
        .USE_SYSTEM_LOGGING_FACILITY = null,
        .VERSION = "1.0.26",
        ._WIN32_WINNT = 0,
        .@"inline" = null, // TODO: ???
    });

    libusb.addConfigHeader(config);
    libusb.addIncludePath(.{ .path = "libusb" });

    libusb.addCSourceFiles(
        &.{
            "libusb/core.c",
            "libusb/descriptor.c",
            "libusb/hotplug.c",
            "libusb/io.c",
            "libusb/strerror.c",
            "libusb/sync.c",
        },
        &.{},
    );

    switch (target.getOsTag()) {
        .linux => {
            libusb.addCSourceFiles(
                &.{
                    "libusb/os/threads_posix.c",
                    "libusb/os/events_posix.c",
                    "libusb/os/linux_usbfs.c",
                    "libusb/os/linux_netlink.c",
                },
                &.{},
            );
            config.addValues(.{
                .HAVE_CLOCK_GETTIME = 1,
                .HAVE_DLFCN_H = 1,
                .HAVE_EVENTFD = 1,
                .HAVE_IOKIT_USB_IOUSBHOSTFAMILYDEFINITIONS_H = null, // TODO
                .HAVE_LIBUDEV = 1, // TODO
                .HAVE_PTHREAD_CONDATTR_SETCLOCK = 1,
                .HAVE_PTHREAD_SETNAME_NP = 1,
                .HAVE_PTHREAD_THREADID_NP = 1,
                ._GNU_SOURCE = 1, // TODO
                .PLATFORM_POSIX = 1,
                .PLATFORM_WINDOWS = null,
            });
        },
        .windows => {
            libusb.addCSourceFiles(
                &.{
                    "libusb/os/threads_windows.c",
                    "libusb/os/events_windows.c",
                    "libusb/os/windows_common.c",
                    "libusb/os/windows_usbdk.c",
                    "libusb/os/windows_winusb.c",
                },
                &.{},
            );
            config.addValues(.{
                .HAVE_CLOCK_GETTIME = null,
                .HAVE_DLFCN_H = null,
                .HAVE_EVENTFD = null,
                .HAVE_IOKIT_USB_IOUSBHOSTFAMILYDEFINITIONS_H = null, // TODO
                .HAVE_LIBUDEV = null, // TODO
                .HAVE_PTHREAD_CONDATTR_SETCLOCK = null,
                .HAVE_PTHREAD_SETNAME_NP = null,
                .HAVE_PTHREAD_THREADID_NP = null,
                ._GNU_SOURCE = null,
                .PLATFORM_POSIX = null,
                .PLATFORM_WINDOWS = 1,
            });
        },
        else => return error.UnuspportedOs,
    }

    b.installArtifact(libusb);
}
