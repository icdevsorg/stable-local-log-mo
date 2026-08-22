import D "mo:core/Debug";
import Runtime "mo:core/Runtime";

import MigrationTypes "../types";
import v0_3_0 "types";

module {
  public func upgrade(
    previous : MigrationTypes.State,
    _args : MigrationTypes.Args,
    _caller : Principal,
    _canister : Principal,
  ) : MigrationTypes.State {
    let old = switch (previous) {
      case (#v0_2_0(#data(state))) state;
      case (_) Runtime.trap("unexpected state version for v0_3_0 upgrade");
    };

    #v0_3_0(#data({ var org_icdevs_ovs_fixed_state = old.org_icdevs_ovs_fixed_state; var bufferSize = old.bufferSize; var entries = old.entries; var startIndex = 0; var minLevel = old.minLevel; var maxMessageSize = old.maxMessageSize; var printLinesToConsole = old.printLinesToConsole }));
  };
};
