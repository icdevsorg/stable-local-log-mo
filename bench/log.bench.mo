import Bench "mo:bench";
import Principal "mo:core/Principal";

import LocalLog "../src";

module {
  func newLogger(capacity : Nat) : LocalLog.Local_log {
    let principal = Principal.fromText("aaaaa-aa");
    LocalLog.Local_log(
      null,
      principal,
      principal,
      ?{ min_level = null; bufferSize = ?capacity },
      ?{
        advanced = null;
        var org_icdevs_timer_tool = null;
        onEvict = null;
      },
      func(_) {},
    );
  };

  public func init() : Bench.Bench {
    let bench = Bench.Bench();
    bench.name("stable-local-log operations");
    bench.rows(["append", "query", "rollover"]);
    bench.cols(["10", "100", "1000"]);

    bench.runner(
      func(row, col) {
        let n = switch (col) { case ("10") 10; case ("100") 100; case (_) 1000 };
        let logger = newLogger(n);
        var i = 0;
        while (i < n) {
          logger.log_info("message", if (i % 2 == 0) "even" else "odd");
          i += 1;
        };

        if (row == "query") {
          ignore logger.log_query({
            namespaces = ?["even"];
            level = ?#Info;
            take = ?n;
            prev = null;
          });
        } else if (row == "rollover") {
          logger.log_info("overflow", "even");
        };
      }
    );
    bench;
  };
};
