param($driveLetter,$isoFilePath)

$src = @"
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace Ripper
{
    public static class DvdRipper
    {
        const int DEFAULT_BUFFER_SIZE = 0x20000;
        
        public static void RipDvd(string driveLetter, string isoFilePath, Action<int> callback)
        {
            if (!driveLetter.EndsWith(":")) driveLetter += ":";

            using (SafeFileHandle hDvd = CreateFileDevice(driveLetter))
            using (Stream input = new FileStream(hDvd, FileAccess.Read))
            using (Stream output = new System.IO.FileStream(isoFilePath, System.IO.FileMode.Create, System.IO.FileAccess.Write))
            {
                long totalSize = new DriveInfo(driveLetter).TotalSize;
                long totalWritten = 0;
                CopyStream(input, output, DEFAULT_BUFFER_SIZE, (int bytesWritten)=>
                {
                    totalWritten += bytesWritten;
                    int percent = (int)(totalWritten*100/totalSize);
                    if (percent<0) percent = 0;
                    if (percent>100) percent=100;
                    if (callback!=null) 
                    {
                        callback(percent);
                    }
                });
            }
        }

        private static void CopyStream(Stream input, Stream output, int bufferSize, Action<int> callback)
        {
            byte[] buffer = new byte[bufferSize];

            int bytesRead;
            while ((bytesRead = input.Read(buffer, 0, bufferSize))>0)
            {
                output.Write(buffer, 0, bytesRead);
                if (callback!=null) callback(bytesRead);
            }
        }

        private static SafeFileHandle CreateFileDevice(string path)
        {
            const uint GENERIC_READ = 0x80000000;
            const uint FILE_SHARE_READ = 0x1;
            const uint OPEN_EXISTING = 0x3;
            const uint FILE_ATTRIBUTE_NORMAL = 0x00000080;

            string szdev = path.EndsWith(@"\") ? path.Substring(0, path.Length - 1) : path;

            IntPtr hdev = CreateFile(@"\\.\" + szdev, GENERIC_READ, FILE_SHARE_READ, IntPtr.Zero, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, IntPtr.Zero);

            return new SafeFileHandle(hdev, true);
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr CreateFile(string lpFileName, uint dwDesiredAccess,uint dwShareMode, IntPtr lpSecurityAttributes, uint dwCreationDisposition, uint wFlagsAndAttributes, IntPtr hTemplateFile);
    }
}
"@

Add-Type -TypeDefinition $src

function progress($i) {
    Write-Progress -Activity "Ripping ..." -status "$driveLetter -> $isoFilePath" -PercentComplete $i
}

[Ripper.DvdRipper]::RipDvd($driveLetter, $isoFilePath, $function:progress)