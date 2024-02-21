DefinitionBlock ("", "SSDT", 1, "DOTLEG", "NVIDIAFU", 1) {
    External (\_SB.PCI0, DeviceObj)

    // NVIDIA GPU stuff
    // The device name is generated by QEMU. See hw/i386/acpi-build.c of QEMU. The number is
    // calculated as (slot << 3 | function), so S00 means slot 0 function 0 and S10 means slot 1
    // function 0. The real one is something like \_SB.PCI0.PEG0.PEGP. Change this if you put your
    // GPU elsewhere in the VM.
    External (\_SB.PCI0.S10.S00, DeviceObj)
    Scope (\_SB.PCI0.S10.S00) {
        Name (FWIT, 0) // fw_cfg initialized
        Name (FWLE, 0) // fw_cfg length
        Name (FWBI, Buffer () { 0 }) // fw_cfg binary

        OperationRegion (FWIO, SystemIO, 0x510, 2) // fw_cfg I/O ports
        Field (FWIO, WordAcc, Lock) {
            FSEL, 16, // Selector
        }
        Field (FWIO, ByteAcc, Lock) {
            Offset (1), // Offset 1 byte
            FDAT, 8, // Data
        }

        // Read a big-endian word
        Method (RWRD, 0, Serialized) {
            Local0 = FDAT << 8
            Local0 |= FDAT
            Return (Local0)
        }

        // Read a big-endian dword
        Method (RDWD, 0, Serialized) {
            Local0 = RWRD () << 16
            Local0 |= RWRD ()
            Return (Local0)
        }

        // Read certain amount of data into a new buffer
        Method (RBUF, 1, Serialized) {
            Local0 = Buffer (Arg0) {}

            For (Local1 = 0, Local1 < Arg0, Local1++) {
                Local0[Local1] = FDAT
            }

            Return (Local0)
        }

        // Find a selector by name
        Method (FISL, 3, Serialized) {
            FSEL = 0x19
            Local0 = RDWD () // Count

            For (Local1 = 0, Local1 < Local0, Local1++) {
                Local2 = RDWD () // Size
                Local3 = RWRD () // Select
                RWRD () // Reserved
                Local4 = ToString (RBUF (56)) // Name

                If (Arg0 == Local4) {
                    Arg1 = Local3
                    Arg2 = Local2
                    Break
                }
            }
        }

        // Initialize ROM
        Method (RINT, 0, Serialized) {
            If (!FWIT) {
                FWIT = 1

                // Checking for fw_cfg existence
                If (!CondRefOf (\_SB.PCI0.FWCF)) {
                    Return ()
                }

                FISL ("opt/com.lion328/nvidia-rom", RefOf (Local0), RefOf (FWLE))

                If (Local0) {
                    FSEL = Local0
                    CopyObject (RBUF (FWLE), FWBI)
                }
            }
        }

        Method (_ROM, 2) {
            RINT ()

            Local0 = Arg1

            // Limit the buffer size to 4KiB per spec
            If (Arg1 > 0x1000) {
                Local0 = 0x1000
            }

            If (Arg0 < FWLE) {
                Return (Mid (FWBI, Arg0, Local0))
            }

            Return (Buffer (Local0) {})
        }
    }

    // Fake battery device at LPC bridge (1f.0)
    External (\_SB.PCI0.SF8, DeviceObj)
    Scope (\_SB.PCI0.SF8) {
        Device (BAT0) {
            Name (_HID, EisaId ("PNP0C0A"))
            Name (_UID, 1)

            Method (_STA) {
                Return (0x0F)
            }
        }
    }
}
