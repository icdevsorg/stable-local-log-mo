import OVS "mo:ovs-fixed";
import TT "mo:timer-tool";
import VectorLib "mo:vector";

module {
  public let TimerTool = TT;
  public let Vector = VectorLib;

  public type ICRC85Environment = OVS.Environment;
  public type ICRC85State = OVS.ICRC85State;
  public type TimerToolType = TT.TimerTool;

  public type LogLevel = { #Debug; #Info; #Warn; #Error; #Fatal };

  public type LogEntry = {
    timestamp : Nat;
    message : Text;
    level : Nat;
    namespace : Text;
  };

  public type InitArgs = {
    min_level : ?LogLevel;
    bufferSize : ?Nat;
  };

  public type Environment = {
    advanced : ?{ icrc85 : ?ICRC85Environment };
    var org_icdevs_timer_tool : ?TT.TimerTool;
    onEvict : ?([LogEntry] -> ());
  };

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

  public type State = {
    var org_icdevs_ovs_fixed_state : OVS.State;
    var bufferSize : Nat;
    var entries : VectorLib.Vector<LogEntry>;
    var startIndex : Nat;
    var minLevel : ?LogLevel;
    var maxMessageSize : Nat;
    var printLinesToConsole : Bool;
  };
};
