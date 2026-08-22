import D "mo:core/Debug";
import Int "mo:core/Int";
import Nat "mo:core/Nat";
import Principal "mo:core/Principal";
import Time "mo:core/Time";
import Vector "mo:vector";

import ClassPlus "mo:class-plus";
import TT "mo:timer-tool";
import ICRC10 "mo:icrc10-mo";

import Local_log ".";
import Service "service";

shared (deployer) persistent actor class Local_logCanister<system>(
  args : ?{
    local_logArgs : ?Local_log.InitArgs;
    ttArgs : ?TT.InitArgList;
  }
) = this {

  transient let debug_channel = {
    var announce = true;
    var timerTool = true;
  };

  transient var vecLog = Vector.new<Text>();

  private func d(doLog : Bool, message : Text) {
    if (doLog) {
      Vector.add(vecLog, Nat.toText(Int.abs(Time.now())) # " " # message);
      if (Vector.size(vecLog) > 5000) {
        vecLog := Vector.new<Text>();
      };
      D.print(message);
    };
  };

  transient let _thisPrincipal = Principal.fromActor(this);
  var _owner = deployer.caller;

  transient let initManager = ClassPlus.ClassPlusInitializationManager<system>(_owner, Principal.fromActor(this), true);

  transient let local_logInitArgs = do ? { args!.local_logArgs! };
  transient let ttInitArgs : ?TT.InitArgList = do ? { args!.ttArgs! };

  var icrc10 = ICRC10.initCollection();

  private func reportTTExecution(execInfo : TT.ExecutionReport) : Bool {
    debug if (debug_channel.timerTool) D.print("CANISTER: TimerTool Execution: " # debug_show (execInfo));
    return false;
  };

  private func reportTTError(errInfo : TT.ErrorReport) : ?Nat {
    debug if (debug_channel.timerTool) D.print("CANISTER: TimerTool Error: " # debug_show (errInfo));
    return null;
  };

  var tt_migration_state : TT.State = TT.Migration.migration.initialState;

  transient let tt = TT.Init({
    org_icdevs_class_plus_manager = initManager;
    initialState = tt_migration_state;
    args = ttInitArgs;
    pullEnvironment = ?(
      func() : TT.Environment {
        {
          advanced = null;
          reportExecution = ?reportTTExecution;
          reportError = ?reportTTError;
          syncUnsafe = null;
          reportBatch = null;
        };
      }
    );

    onInitialize = ?(
      func(newClass : TT.TimerTool) : async* () {
        D.print("Initializing TimerTool");
        newClass.initialize<system>();
        //do any work here necessary for initialization
      }
    );
    onStorageChange = func(state : TT.State) {
      tt_migration_state := state;
    };
  });

  var local_log_migration_state : Local_log.State = Local_log.initialState();

  transient let local_log = Local_log.Init({
    org_icdevs_class_plus_manager = initManager;
    initialState = local_log_migration_state;
    args = local_logInitArgs;
    pullEnvironment = ?(
      func() : Local_log.Environment {
        {
          var org_icdevs_timer_tool = ?tt();
          advanced = null; // Add any advanced options if needed
          onEvict = null;
        };
      }
    );

    onInitialize = ?(
      func(newClass : Local_log.Local_log) : async* () {
        D.print("Initializing Local_log Class");
      }
    );

    onStorageChange = func(state : Local_log.State) {
      local_log_migration_state := state;
    };
  });

  // Expose logger as required by Service interface
  transient let logger = local_log();

  public shared ({ caller = _ }) func log_add(message : Text, level : Service.LogLevel, namespace : Text) : async () {
    logger.log_add(message, level, namespace);
  };

  public query func log_query(q : Service.LogQuery) : async [Service.LogEntry] {
    logger.log_query(q);
  };

  public shared ({ caller = _ }) func log_clear() : async Nat {
    logger.log_clear();
  };

  public query func log_export(q : Service.LogQuery) : async Service.LogExportResult {
    logger.log_export(q);
  };

  public query func log_size(ns : ?[Text], lvl : ?Service.LogLevel) : async Nat {
    logger.log_size(ns, lvl);
  };

  public shared ({ caller = _ }) func log_set_buffer_size(size : Nat) : async Nat {
    logger.log_set_buffer_size(size);
  };

  public query func log_get_buffer_size() : async Nat {
    logger.log_get_buffer_size();
  };

  public query func get_stats() : async Local_log.Stats {
    let stats = logger.getStats();
    return stats;
  };

  public query func get_icrc10() : async ICRC10.Response {
    return ICRC10.respond(icrc10);
  };

  public shared func hello() : async Text {
    return "world!";
  };
};
