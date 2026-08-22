import MigrationTypes "migrations/types";
import MigrationLib "migrations";
import ClassPlusLib "mo:class-plus";
import Array "mo:core/Array";
import Iter "mo:core/Iter";
import Nat "mo:core/Nat";
import Service "service";
import D "mo:core/Debug";
import Runtime "mo:core/Runtime";
import OVSFixed "mo:ovs-fixed";
import Int "mo:core/Int";
import Time "mo:core/Time";
import Vector "mo:vector";
import Text "mo:core/Text";

module {

  public let Migration = MigrationLib;
  public let TT = MigrationLib.TimerTool;
  public type State = MigrationTypes.State;
  public type CurrentState = MigrationTypes.Current.State;
  public type Environment = MigrationTypes.Current.Environment;
  public type Stats = MigrationTypes.Current.Stats;
  public type InitArgs = MigrationTypes.Current.InitArgs;
  public type ICRC85Environment = MigrationTypes.Current.ICRC85Environment;

  public let init = Migration.migrate;

  public func initialState() : State { #v0_0_0(#data) };
  public let currentStateVersion = #v0_3_0(#id);

  public let ICRC85_NAMESPACE = "com.panindustrial.libraries.local_log";
  public let ICRC85_TIMER_NAMESPACE = "icrc85:ovs:shareaction:local_log";
  public let ONE_XDR = 1_000_000_000_000;
  public let ONE_DAY = 86_400_000_000_000;

  public func test() : Nat {
    1;
  };

  public func levelToNat(level : MigrationTypes.Current.LogLevel) : Nat {
    switch (level) {
      case (#Debug) 0;
      case (#Info) 1;
      case (#Warn) 2;
      case (#Error) 3;
      case (#Fatal) 4;
    };
  };

  public func Init(
    config : {
      org_icdevs_class_plus_manager : ClassPlusLib.ClassPlusInitializationManager;
      initialState : State;
      args : ?InitArgs;
      pullEnvironment : ?(() -> Environment);
      onInitialize : ?(Local_log -> async* ());
      onStorageChange : ((State) -> ());
    }
  ) : () -> Local_log {

    switch (config.pullEnvironment) {
      case (?_val) {};
      case (null) {
        Runtime.trap("environment required");
      };
    };

    let wrappedOnInitialize = func(instance : Local_log) : async* () {
      ///////////
      // ICRC-85 Open Value Sharing
      ///////////
      let ovsConfig : OVSFixed.InitArgs = {
        namespace = ICRC85_NAMESPACE;
        publicNamespace = ICRC85_TIMER_NAMESPACE;
        baseCycles = 200_000_000_000; // .2 XDR
        actionDivisor = 10000;
        actionMultiplier = 200_000_000_000; // .2 XDR
        maxCycles = ONE_XDR;
        initialWait = ?(ONE_DAY * 7);
        period = null; // default 30 days
        asset = null; // default Cycles
        platform = null; // default ICP
        resetAtEndOfPeriod = true;
      };

      var org_icdevs_class_plus_manager = ClassPlusLib.ClassPlusInitializationManager<system>(instance.caller, instance.canister, true);

      func getOVSEnv() : OVSFixed.Environment {
        {
          var org_icdevs_timer_tool = instance.environment.org_icdevs_timer_tool;
          var collector = do ? {
            instance.environment.advanced!.icrc85!.collector!;
          };
          advanced = do ? { instance.environment.advanced!.icrc85!.advanced! };
        };
      };

      instance.org_icdevs_ovs_fixed := ?OVSFixed.Init({
        org_icdevs_class_plus_manager = org_icdevs_class_plus_manager;
        args = ?ovsConfig;
        pullEnvironment = ?getOVSEnv;
        onInitialize = null;
        initialState = instance.state.org_icdevs_ovs_fixed_state;
        onStorageChange = func(_state : OVSFixed.State) {
          instance.state.org_icdevs_ovs_fixed_state := _state;
        };
      });

      switch (config.onInitialize) {
        case (?cb) await* cb(instance);
        case (null) {};
      };
    };

    ClassPlusLib.ClassPlus<Local_log, State, InitArgs, Environment>({
      config with
      constructor = Local_log;
      onInitialize = ?wrappedOnInitialize;
    }).get;
  };

  /// Main logging class used internally and by canisters/classes as a module
  public class Local_log(
    stored : ?State,
    caller_ : Principal,
    canister_ : Principal,
    args : ?InitArgs,
    environment_passed : ?Environment,
    storageChanged : (State) -> (),
  ) {

    public let caller = caller_;
    public let canister = canister_;

    public let debug_channel = { var announce = true };
    public let environment = switch (environment_passed) {
      case (?val) val;
      case (null) { Runtime.trap("Environment is required") };
    };

    // Keep other state as before
    public var state : CurrentState = switch (stored) {
      case (null) {
        switch (init(initialState(), currentStateVersion, args, caller_, canister_)) {
          case (#v0_3_0(#data(foundState))) foundState;
          case (_) Runtime.trap("unexpected migration tag");
        };
      };
      case (?val) {
        switch (init(val, currentStateVersion, args, caller_, canister_)) {
          case (#v0_3_0(#data(foundState))) foundState;
          case (_) Runtime.trap("unexpected migration tag");
        };
      };
    };
    storageChanged(#v0_3_0(#data(state)));

    /// OVS instance - initialized later by Init wrapper
    public var org_icdevs_ovs_fixed : ?(() -> OVSFixed.OVS) = null;

    // Core log functions
    private func nowNat() : Nat = Int.abs(Time.now());

    /// Internal utility: Test if log level passes configured minimum level
    private func passesLevel(level : MigrationTypes.Current.LogLevel) : Bool {
      switch (state.minLevel) {
        case (null) true;
        case (?#Debug) true;
        case (?#Info) {
          switch (level) {
            case (#Debug) false;
            case (_) true;
          };

        };
        case (?#Warn) {
          switch (level) {
            case (#Debug) false;
            case (#Info) false;
            case (_) true;
          };
        };
        case (?#Error) {
          switch (level) {
            case (#Debug) false;
            case (#Info) false;
            case (#Warn) false;
            case (_) true;
          };
        };
        case (?#Fatal) {
          switch (level) {
            case (#Fatal) true;
            case (_) false;
          };
        };
      };
    };

    /// Internal: Check if any namespace matches
    private func inNamespaces(namespaces : [Text], search : Text) : Bool {
      for (ns in namespaces.vals()) if (ns == search) return true;
      false;
    };

    private func entryAt(logicalIndex : Nat) : MigrationTypes.Current.LogEntry {
      let size = Vector.size(state.entries);
      Vector.get(state.entries, (state.startIndex + logicalIndex) % size);
    };

    private func entriesInOrder() : [MigrationTypes.Current.LogEntry] {
      Array.tabulate(Vector.size(state.entries), entryAt);
    };

    //add public shortcut to log for each level
    public func log_debug(message : Text, namespace : Text) : () {
      log_add(message, #Debug, namespace);
    };
    public func log_info(message : Text, namespace : Text) : () {
      log_add(message, #Info, namespace);
    };
    public func log_warn(message : Text, namespace : Text) : () {
      log_add(message, #Warn, namespace);
    };
    public func log_error(message : Text, namespace : Text) : () {
      log_add(message, #Error, namespace);
    };
    public func log_fatal(message : Text, namespace : Text) : () {
      log_add(message, #Fatal, namespace);
    };

    /// Add one log entry to buffer for each namespace
    public func log_add(message : Text, level : MigrationTypes.Current.LogLevel, namespace : Text) : () {

      if (not passesLevel(level)) return;
      let finalText = if (message.size() > state.maxMessageSize) {
        let modified = Text.fromIter(Iter.take(Text.toIter(message), state.maxMessageSize));
        modified # "...";
      } else {
        message;
      };

      state.org_icdevs_ovs_fixed_state.activeActions += 1;

      let entry : MigrationTypes.Current.LogEntry = {
        timestamp = nowNat();
        message = finalText;
        level = levelToNat(level);
        namespace = namespace;
      };
      if (state.bufferSize == 0) return;

      let size = Vector.size(state.entries);
      if (size < state.bufferSize) {
        Vector.add(state.entries, entry);
      } else {
        let evicted = Vector.get(state.entries, state.startIndex);
        switch (environment.onEvict) {
          case (?handler) handler([evicted]);
          case null {};
        };
        Vector.put(state.entries, state.startIndex, entry);
        state.startIndex := (state.startIndex + 1) % state.bufferSize;
      };
      if (state.printLinesToConsole) {
        debug D.print(debug_show (entry));
      };
    };

    /// Query log entries with optional filtering
    public func log_query(q : Service.LogQuery) : [MigrationTypes.Current.LogEntry] {
      let nsFilter = q.namespaces;
      let lvlFilter = q.level;
      let buf = Vector.new<MigrationTypes.Current.LogEntry>();
      var skip : Nat = switch (q.prev) { case (null) 0; case (?n) n };
      var added = 0;
      let max = switch (q.take) { case (null) 1000; case (?m) m };
      let size = Vector.size(state.entries);
      if (size == 0 or max == 0) return [];
      label filter for (i in Nat.range(0, size)) {
        if (i < skip) continue filter;
        let e = entryAt(i);
        switch (nsFilter) {
          case (null) {};
          case (?arr) {
            if (not inNamespaces(arr, e.namespace)) continue filter;
          };
        };
        switch (lvlFilter) {
          case (null) {};
          case (?lev) {
            let test = levelToNat(lev);
            if (e.level < test) continue filter;
          };
        };
        Vector.add(buf, e);
        added += 1;
        if (added >= max) break filter;
      };
      Vector.toArray(buf);
    };

    /// Remove all or selected log entries, return number dropped
    public func log_clear() : Nat {
      state.org_icdevs_ovs_fixed_state.activeActions += 1;

      let original = Vector.size(state.entries);
      switch (environment.onEvict) {
        case (?handler) {
          handler(entriesInOrder());
        };
        case _ ();
      };
      Vector.clear(state.entries);
      state.startIndex := 0;

      let removed = original - Vector.size(state.entries);
      removed;
    };

    /// Export entire or filtered log as structure
    public func log_export(q : Service.LogQuery) : Service.LogExportResult {
      let result = log_query(q);
      { exportedCount = result.size(); exported = result };
    };

    /// The log buffer size (optionally filtered)
    public func log_size(ns : ?[Text], lvl : ?MigrationTypes.Current.LogLevel) : Nat {
      var n = 0;
      let size = Vector.size(state.entries);
      if (size == 0) return 0;
      label count for (i in Nat.range(0, size)) {
        let e = entryAt(i);
        switch (ns) {
          case (null) {};
          case (?arr) { if (not inNamespaces(arr, e.namespace)) continue count };
        };
        switch (lvl) {
          case (null) {};
          case (?lev) {
            let test = levelToNat(lev);
            if (e.level < test) continue count;
          };
        };
        n += 1;
      };
      n;
    };

    /// Set the maximum buffer size for the logger, returns new value
    public func log_set_buffer_size(v : Nat) : Nat {
      if (v == 0) return state.bufferSize;
      state.bufferSize := v;
      // if log is oversized, truncate
      let curSize = Vector.size(state.entries);
      if (curSize > v) {
        let dropCount = curSize - v;
        let dropped = Array.tabulate(dropCount, entryAt);
        switch (environment.onEvict) {
          case (?handler) handler(dropped);
          case null {};
        };
        let retained = Vector.new<MigrationTypes.Current.LogEntry>();
        var i = dropCount;
        while (i < curSize) {
          Vector.add(retained, entryAt(i));
          i += 1;
        };
        state.entries := retained;
        state.startIndex := 0;
      };

      state.bufferSize;
    };

    public func log_set_min_level(level : MigrationTypes.Current.LogLevel) : Nat {
      state.minLevel := ?level;
      levelToNat(level);
    };

    /// Get the maximum buffer size
    public func log_get_buffer_size() : Nat { state.bufferSize };

    public func getState() : MigrationTypes.Current.State {
      state;
    };

    public func getStats() : Stats {
      let stats : Stats = {
        icrc85 = {
          nextCycleActionId = state.org_icdevs_ovs_fixed_state.nextCycleActionId;
          lastActionReported = state.org_icdevs_ovs_fixed_state.lastActionReported;
          activeActions = state.org_icdevs_ovs_fixed_state.activeActions;
        };
        bufferSize = state.bufferSize;
        minLevel = state.minLevel;
        log = entriesInOrder();
      };
      stats;
    };
  };
};
