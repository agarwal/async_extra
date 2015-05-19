
(** An actively maintained rpc connection that eagerly and repeatedly attempts to
    reconnect whenever the connection is lost, until a new connection is established. *)

open Core.Std
open Import

type t

module Event : sig
  type t =
    | Attempting_to_connect
    | Obtained_address      of Host_and_port.t
    | Failed_to_connect     of Error.t
    | Connected
    | Disconnected
  with sexp
end

(** [create ~server_name ~log get_address] returns a persistent rpc connection to a server
    whose host and port are obtained via [get_address] every time we try to connect.  For
    example, [get_address] might look up a server's host and port in catalog at a
    particular path to which multiple redundant copies of a service are publishing their
    location.  If one copy dies, we get the address of the another one when looking up the
    address afterwards.

    All connection events (see the type above) are passed to the [on_event] callback, if
    given.  If a [~log] is supplied then these events will be written there as well, with
    a "persistent-connection-to" tag value of [server_name], which should be the name of
    the server we are connecting to.

    [`Failed_to_connect error] and [`Obtained_address addr] events are only reported if
    they are distinct from the most recent event of the same type that has taken place
    since the most recent [`Attempting_to_connect] event.

    The [via_local_interface], [implementations], [max_message_size], [make_transport],
    [handshake_timeout], and [heartbeat_config] arguments are just as for
    [Rpc.Connection.create]. *)
val create
  :  server_name          : string
  -> ?log                 : Log.t
  -> ?on_event            : (Event.t -> unit)
  -> ?via_local_interface : Unix.Inet_addr.t
  -> ?implementations     : _ Rpc.Connection.Client_implementations.t
  -> ?max_message_size    : int
  -> ?make_transport      : Rpc.Connection.transport_maker
  -> ?handshake_timeout   : Time.Span.t
  -> ?heartbeat_config    : Rpc.Connection.Heartbeat_config.t
  -> (unit -> Host_and_port.t Or_error.t Deferred.t)
  -> t

(** like [create], but generic in the function used to connect *)
val create_generic
  :  server_name : string
  -> ?log        : Log.t
  -> ?on_event   : (Event.t -> unit)
  -> connect     : (Host_and_port.t -> Rpc.Connection.t Or_error.t Deferred.t)
  -> (unit -> Host_and_port.t Or_error.t Deferred.t)
  -> t

(** [connected] returns the first available rpc connection from the time it is called.
    When currently connected, the returned deferred is already determined.
    If [closed] has been called, then the returned deferred is never determined. *)
val connected : t -> Rpc.Connection.t Deferred.t

(** The current rpc connection, if any. *)
val current_connection : t -> Rpc.Connection.t option

(** [close t] closes the current connection and stops it from trying to reconnect.  After
    the deferred it returns becomes determined, the last connection has been closed and no
    others will be attempted.

    [close_finished t] becomes determined at the same time as the result of the first call
    to [close].  [close_finished] differs from [close] in that it does not have the side
    effect of initiating a close. *)
val close : t -> unit Deferred.t
val close_finished : t -> unit Deferred.t
