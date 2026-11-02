//===----------------------------------------------------------------------===//
// Copyright © 2026 Apple Inc. and the container project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//

import Containerization

/// Sizes the VM from the container's estimated working set, shrinking slowly while the guest is
/// not under memory pressure and growing quickly as soon as it is.
///
/// The target is only a request to the guest balloon driver; the guest may honor it partly or never.
struct WorkingSetBalloonPolicy {
    /// Never ask the guest to keep less than this.
    var minimumBytes: UInt64 = 512 << 20
    /// Extra room kept above the working set estimate, as a fraction of it.
    var headroom: Double = 0.25
    /// Largest shrink per sample, as a fraction of the configured memory.
    var shrinkStepFraction: Double = 0.05
    /// Growth per sample while under pressure, as a fraction of the configured memory.
    var growStepFraction: Double = 0.25

    private var lastPressure: UInt64?

    init() {}

    /// - Parameters:
    ///   - stats: The latest memory statistics of the container.
    ///   - currentTarget: The target currently requested from the VM, in bytes.
    ///   - configured: The VM's configured memory, in bytes. This is the upper bound for the target.
    /// - Returns: The new target in bytes. The caller rounds it to a multiple of 1 MiB and clamps it to `configured`.
    mutating func nextTarget(
        stats: ContainerStatistics.MemoryStatistics,
        currentTarget: UInt64,
        configured: UInt64
    ) -> UInt64 {
        // 1. How much memory do we think the guest needs?
        let ideal = idealTarget(stats: stats, configured: configured)

        // 2. Is the guest struggling at its current size?
        let pressure = stats.workingsetRefaultFile + stats.workingsetRefaultAnon + stats.pgstealDirect
        // The counters only increase, so pressure means they grew since the previous sample.
        let underPressure = lastPressure.map { pressure > $0 } ?? false
        lastPressure = pressure

        // 3. Move toward the ideal target: grow fast, shrink slowly.
        if underPressure {
            // Give memory back quickly, and never less than the ideal target.
            let grown = currentTarget + UInt64(Double(configured) * growStepFraction)
            return min(max(grown, ideal), configured)
        }
        if ideal >= currentTarget {
            // The guest needs more than it has.
            return ideal
        }
        // The guest has more than it needs. Shrink a little at a time, but not below the ideal target.
        let step = UInt64(Double(configured) * shrinkStepFraction)
        let shrunk = currentTarget > step ? currentTarget - step : 0
        return max(shrunk, ideal)
    }

    /// The working set estimate plus headroom, kept within `minimumBytes` and `configured`.
    private func idealTarget(stats: ContainerStatistics.MemoryStatistics, configured: UInt64) -> UInt64 {
        // `cacheBytes` includes inactive file pages, which the guest can drop cheaply.
        let activeFile = stats.cacheBytes > stats.inactiveFile ? stats.cacheBytes - stats.inactiveFile : 0
        // Guest kernel and vminitd live outside the container cgroup, so add a flat allowance for them.
        let workingSet = stats.anon + activeFile + stats.slabBytes + stats.kernelStackBytes + VMResources.guestMemoryOverhead
        let withHeadroom = UInt64(Double(workingSet) * (1 + headroom))
        return min(max(withHeadroom, minimumBytes), configured)
    }
}
