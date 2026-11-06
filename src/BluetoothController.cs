// SPDX-License-Identifier: MIT
// Original implementation of documented Windows Bluetooth APIs.
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Globalization;
using System.Runtime.InteropServices;

namespace DualSenseBluetoothOff {
    public class Controller {
        public string Address;
        public string Name;
        public bool Connected;
        public bool Paired;
        public bool Remembered;
    }

    public sealed class ControllerStatus : Controller {
        public bool Known;
        public bool Complete;
        public List<string> Errors = new List<string>();
    }

    public sealed class DisconnectRequest {
        public bool Attempted;
        public bool IoctlReturnedSuccess;
        public List<int> Win32Errors = new List<int>();
    }

    public static class Native {
        public const uint DisconnectIoctl = 0x0041000C;
        public const uint DisconnectInputSize = 8;
        private const int NoMoreItems = 259;

        [StructLayout(LayoutKind.Sequential)]
        private struct RadioParams { public uint Size; }

        [StructLayout(LayoutKind.Sequential)]
        private struct SystemTime {
            public ushort Year, Month, DayOfWeek, Day, Hour, Minute, Second, Milliseconds;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct DeviceInfo {
            public uint Size;
            public ulong Address;
            public uint ClassOfDevice;
            [MarshalAs(UnmanagedType.Bool)] public bool Connected;
            [MarshalAs(UnmanagedType.Bool)] public bool Remembered;
            [MarshalAs(UnmanagedType.Bool)] public bool Authenticated;
            public SystemTime LastSeen;
            public SystemTime LastUsed;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 248)] public string Name;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct SearchParams {
            public uint Size;
            [MarshalAs(UnmanagedType.Bool)] public bool ReturnAuthenticated;
            [MarshalAs(UnmanagedType.Bool)] public bool ReturnRemembered;
            [MarshalAs(UnmanagedType.Bool)] public bool ReturnUnknown;
            [MarshalAs(UnmanagedType.Bool)] public bool ReturnConnected;
            [MarshalAs(UnmanagedType.Bool)] public bool IssueInquiry;
            public byte TimeoutMultiplier;
            public IntPtr Radio;
        }

        [DllImport("bthprops.cpl", SetLastError = true)]
        private static extern IntPtr BluetoothFindFirstRadio(ref RadioParams parameters, out IntPtr radio);
        [DllImport("bthprops.cpl", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool BluetoothFindNextRadio(IntPtr search, out IntPtr radio);
        [DllImport("bthprops.cpl", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool BluetoothFindRadioClose(IntPtr search);
        [DllImport("bthprops.cpl", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr BluetoothFindFirstDevice(ref SearchParams parameters, ref DeviceInfo info);
        [DllImport("bthprops.cpl", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool BluetoothFindNextDevice(IntPtr search, ref DeviceInfo info);
        [DllImport("bthprops.cpl", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool BluetoothFindDeviceClose(IntPtr search);
        [DllImport("bthprops.cpl", CharSet = CharSet.Unicode)]
        private static extern uint BluetoothGetDeviceInfo(IntPtr radio, ref DeviceInfo info);
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool DeviceIoControl(IntPtr device, uint controlCode,
            ref ulong input, uint inputSize, IntPtr output, uint outputSize,
            out uint returned, IntPtr overlapped);

        public static int DeviceInfoSize { get { return Marshal.SizeOf(typeof(DeviceInfo)); } }
        public static int SearchParamsSize { get { return Marshal.SizeOf(typeof(SearchParams)); } }

        public static bool IsSupportedName(string name) {
            return String.Equals(name, "DualSense Wireless Controller", StringComparison.OrdinalIgnoreCase)
                || String.Equals(name, "DualSense Edge Wireless Controller", StringComparison.OrdinalIgnoreCase);
        }

        public static string FormatAddress(ulong address) {
            string hex = address.ToString("X12", CultureInfo.InvariantCulture);
            var parts = new string[6];
            for (int i = 0; i < 6; i++) parts[i] = hex.Substring(i * 2, 2);
            return String.Join(":", parts);
        }

        private static List<IntPtr> Radios() {
            var handles = new List<IntPtr>();
            var parameters = new RadioParams { Size = (uint)Marshal.SizeOf(typeof(RadioParams)) };
            IntPtr radio;
            IntPtr search = BluetoothFindFirstRadio(ref parameters, out radio);
            if (search == IntPtr.Zero) {
                int error = Marshal.GetLastWin32Error();
                throw new Win32Exception(error, "Cannot access Bluetooth: " + new Win32Exception(error).Message);
            }
            try {
                handles.Add(radio);
                while (BluetoothFindNextRadio(search, out radio)) handles.Add(radio);
                int error = Marshal.GetLastWin32Error();
                if (error != 0 && error != NoMoreItems) throw new Win32Exception(error);
                return handles;
            } catch {
                foreach (IntPtr handle in handles) CloseHandle(handle);
                throw;
            } finally { BluetoothFindRadioClose(search); }
        }

        private static DeviceInfo Info(ulong address) {
            return new DeviceInfo { Size = (uint)DeviceInfoSize, Address = address };
        }

        public static Controller[] ListControllers() {
            var radios = Radios();
            var devices = new Dictionary<ulong, Controller>();
            try {
                foreach (IntPtr radio in radios) {
                    var parameters = new SearchParams {
                        Size = (uint)SearchParamsSize, Radio = radio,
                        ReturnAuthenticated = true, ReturnRemembered = true,
                        ReturnConnected = true, ReturnUnknown = false, IssueInquiry = false
                    };
                    var info = Info(0);
                    IntPtr search = BluetoothFindFirstDevice(ref parameters, ref info);
                    if (search == IntPtr.Zero) {
                        int error = Marshal.GetLastWin32Error();
                        if (error == NoMoreItems) continue;
                        throw new Win32Exception(error);
                    }
                    try {
                        while (true) {
                            if (IsSupportedName(info.Name)) {
                                Controller device;
                                if (!devices.TryGetValue(info.Address, out device)) {
                                    device = new Controller { Address = FormatAddress(info.Address), Name = info.Name };
                                    devices.Add(info.Address, device);
                                }
                                device.Connected |= info.Connected;
                                device.Paired |= info.Authenticated;
                                device.Remembered |= info.Remembered;
                            }
                            info = Info(0);
                            if (!BluetoothFindNextDevice(search, ref info)) {
                                int error = Marshal.GetLastWin32Error();
                                if (error != NoMoreItems) throw new Win32Exception(error);
                                break;
                            }
                        }
                    } finally { BluetoothFindDeviceClose(search); }
                }
                var values = new List<Controller>(devices.Values);
                values.Sort(delegate(Controller a, Controller b) { return String.CompareOrdinal(a.Address, b.Address); });
                return values.ToArray();
            } finally { foreach (IntPtr radio in radios) CloseHandle(radio); }
        }

        public static ControllerStatus GetState(ulong address) {
            var radios = Radios();
            var state = new ControllerStatus { Address = FormatAddress(address) };
            try {
                foreach (IntPtr radio in radios) {
                    var info = Info(address);
                    uint error = BluetoothGetDeviceInfo(radio, ref info);
                    if (error != 0) {
                        state.Errors.Add("BluetoothGetDeviceInfo: " + error + " (" + new Win32Exception((int)error).Message + ")");
                        continue;
                    }
                    state.Known = true;
                    state.Connected |= info.Connected;
                    state.Paired |= info.Authenticated;
                    state.Remembered |= info.Remembered;
                    state.Name = info.Name;
                }
                state.Complete = state.Errors.Count == 0;
                return state;
            } finally { foreach (IntPtr radio in radios) CloseHandle(radio); }
        }

        public static DisconnectRequest Disconnect(ulong address, string expectedName) {
            var radios = Radios();
            var targets = new List<IntPtr>();
            var request = new DisconnectRequest();
            try {
                // Validate all queried radios before changing any connection.
                foreach (IntPtr radio in radios) {
                    var info = Info(address);
                    uint error = BluetoothGetDeviceInfo(radio, ref info);
                    if (error != 0) throw new Win32Exception((int)error);
                    if (!IsSupportedName(info.Name) || !String.Equals(info.Name, expectedName, StringComparison.OrdinalIgnoreCase))
                        throw new InvalidOperationException("Controller identity changed; disconnect cancelled.");
                    if (info.Connected) targets.Add(radio);
                }
                foreach (IntPtr radio in targets) {
                    request.Attempted = true;
                    uint returned;
                    ulong input = address;
                    bool success = DeviceIoControl(radio, DisconnectIoctl, ref input, DisconnectInputSize,
                        IntPtr.Zero, 0, out returned, IntPtr.Zero);
                    int error = success ? 0 : Marshal.GetLastWin32Error();
                    request.IoctlReturnedSuccess |= success;
                    if (!success) request.Win32Errors.Add(error);
                }
                return request;
            } finally { foreach (IntPtr radio in radios) CloseHandle(radio); }
        }
    }
}
