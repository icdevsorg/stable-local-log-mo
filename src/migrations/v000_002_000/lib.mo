import MigrationTypes "../types";
import v0_2_0 "types";
import D "mo:core/Debug";
import Runtime "mo:core/Runtime";

module {

  let Vector = v0_2_0.Vector;

  public func upgrade(prevmigration_state : MigrationTypes.State, args : MigrationTypes.Args, _caller : Principal, _canister : Principal) : MigrationTypes.State {
    let state = switch (prevmigration_state) {
      case (#v0_1_0(#data(s))) s;
      case (_) Runtime.trap("unexpected state version for v0_2_0 upgrade");
    };

    let (minLevel, bufferSize) = switch (args) {
      case (?a) { (a.min_level, a.bufferSize) };
      case (null) { (null, null) };
    };

    let newState : v0_2_0.State = {
      var org_icdevs_ovs_fixed_state = {
        var nextCycleActionId = state.icrc85.nextCycleActionId;
        var lastActionReported = state.icrc85.lastActionReported;
        var activeActions = state.icrc85.activeActions;
        var resetAtEndOfPeriod = true;
      };
      var bufferSize = switch (bufferSize) {
        case (?sz) sz;
        case (null) state.bufferSize;
      };
      var entries = state.entries;
      var minLevel = switch (minLevel) {
        case (?lvl) ?lvl;
        case (null) state.minLevel;
      };
      var maxMessageSize = state.maxMessageSize;
      var printLinesToConsole = state.printLinesToConsole;
    };

    return #v0_2_0(#data(newState));
  };
};
