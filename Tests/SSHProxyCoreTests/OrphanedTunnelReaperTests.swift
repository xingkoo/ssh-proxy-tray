import XCTest
@testable import SSHProxyCore

final class OrphanedTunnelReaperTests: XCTestCase {
    func testFindsOnlyStrictlyIdentifiedOrphanedTunnels() {
        let processList = """
          101     1 /usr/bin/ssh -o ControlMaster=yes -o ControlPersist=no -o ControlPath=/tmp/spt-C79657D2-39F.sock -N qiniu
          102   900 /usr/bin/ssh -o ControlMaster=yes -o ControlPersist=no -o ControlPath=/tmp/spt-B2838C38-B9F.sock -N oracle1
          103     1 /usr/bin/ssh -N qiniu
          104     1 /usr/bin/ssh -o ControlMaster=yes -o ControlPersist=no -o ControlPath=/tmp/other.sock -N qiniu
          105     1 /usr/local/bin/ssh -o ControlMaster=yes -o ControlPersist=no -o ControlPath=/tmp/spt-12345678-ABC.sock -N qiniu
        """

        XCTAssertEqual(
            OrphanedTunnelReaper.candidates(from: processList),
            [
                OrphanedTunnelProcess(
                    pid: 101,
                    parentPID: 1,
                    controlSocketPath: "/tmp/spt-C79657D2-39F.sock"
                )
            ]
        )
    }

    func testRejectsMalformedManagedSocketNames() {
        let processList = """
          201     1 /usr/bin/ssh -o ControlMaster=yes -o ControlPersist=no -o ControlPath=/tmp/spt-../../bad.sock -N qiniu
          202     1 /usr/bin/ssh -o ControlMaster=yes -o ControlPersist=no -o ControlPath=/tmp/spt-1234.sock -N qiniu
          203     1 /usr/bin/ssh -o ControlMaster=yes -o ControlPersist=no -o ControlPath=/tmp/spt-ZZZZZZZZ-ZZZ.sock -N qiniu
        """

        XCTAssertTrue(OrphanedTunnelReaper.candidates(from: processList).isEmpty)
    }
}
