import OVS "mo:ovs-fixed";
import TT "mo:timer-tool";
import VectorLib "mo:vector";

// please do not import any types from your project outside migrations folder here
// it can lead to bugs when you change those types later, because migration types should not be changed
// you should also avoid importing these types anywhere in your project directly from here
// use MigrationTypes.Current property instead

module {
  public let TimerTool = TT;
  public let Vector = VectorLib;

  /// Re-export OVS types for external use
  public type ICRC85Environment = OVS.Environment;
  public type ICRC85State = OVS.ICRC85State;

  /// Re-export TimerTool type for external use
  public type TimerToolType = TT.TimerTool;

  // LogLevel compatible with public service.mo
  public type LogLevel = {
    #Debug;
    #Info;
    #Warn;
    #Error;
    #Fatal;
  };

  public type LogEntry = {
    timestamp : Nat;
    message : Text;
    level : Nat;
    namespace : Text;
  };

  public type InitArgs = {
    min_level : ?LogLevel; // minimum log level (optional)
    bufferSize : ?Nat; // max buffer size
  };

  public type Environment = {
    advanced : ?{
      icrc85 : ?ICRC85Environment;
    };
    /// TimerTool instance for scheduling ICRC-85 cycle shares
    /// Pass the same TimerTool instance to all components in your canister
    var org_icdevs_timer_tool : ?TT.TimerTool;
    onEvict : ?([LogEntry] -> ()); // Optional handler for removed (evicted) records
  };

  // Stats exposes key State fields for read-only inspection/debugging
  public type Stats = {
    icrc85 : {
      nextCycleActionId : ?Nat;
      lastActionReported : ?Nat;
      activeActions : Nat;
    };
    bufferSize : Nat;
    minLevel : ?LogLevel;
    log : [LogEntry];
  };

  ///MARK: State
  public type State = {
    var org_icdevs_ovs_fixed_state : OVS.State;
    var bufferSize : Nat; // log buffer maximum size; controls rollover
    var entries : VectorLib.Vector<LogEntry>;
    var minLevel : ?LogLevel; // optional minimum log level for this logger
    var maxMessageSize : Nat; // maximum message size
    var printLinesToConsole : Bool;
  };
};
