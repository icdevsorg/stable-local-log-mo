import Debug "mo:core/Debug";
import Principal "mo:core/Principal";

import LocalLog "../src";
import Types "../src/migrations/types";

let principal = Principal.fromText("aaaaa-aa");
var stored = LocalLog.initialState();
var evicted : [Types.Current.LogEntry] = [];

let logger = LocalLog.Local_log(
  null,
  principal,
  principal,
  ?{ min_level = ?#Info; bufferSize = ?3 },
  ?{
    advanced = null;
    var org_icdevs_timer_tool = null;
    onEvict = ?(func(entries) { evicted := entries });
  },
  func(state) { stored := state },
);

assert (logger.log_query({ namespaces = null; level = null; take = null; prev = null }).size() == 0);

logger.log_debug("hidden", "app");
logger.log_info("one", "app");
logger.log_warn("two", "db");
assert (logger.log_size(null, null) == 2);
assert (logger.log_size(?["app"], null) == 1);
assert (logger.log_size(null, ?#Warn) == 1);

logger.log_info("1234567890", "app");
assert (logger.log_size(null, null) == 3);

logger.log_info("four", "app");
let retained = logger.log_query({
  namespaces = null;
  level = null;
  take = null;
  prev = null;
});
assert (retained.size() == 3);
assert (retained[0].message == "two");
assert (evicted.size() == 1);
assert (evicted[0].message == "one");

assert (logger.log_clear() == 3);
assert (logger.log_size(null, null) == 0);

Debug.print("stable-local-log tests passed");
