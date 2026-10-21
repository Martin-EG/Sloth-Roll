import Darwin

/// Reads this process's memory footprint (what iOS counts against the jetsam limit).
enum MemoryProbe {
    /// Current physical footprint in bytes, or nil if the kernel call fails.
    static func footprintBytes() -> UInt64? {
        vmInfo()?.phys_footprint
    }

    /// Highest physical footprint since launch, in bytes.
    static func peakFootprintBytes() -> UInt64? {
        vmInfo().map { UInt64(clamping: $0.ledger_phys_footprint_peak) }
    }

    private static func vmInfo() -> task_vm_info_data_t? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info : nil
    }
}
