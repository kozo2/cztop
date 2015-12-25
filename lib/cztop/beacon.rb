module CZTop
  # Used for LAN discovery and presence.
  # @see http://api.zeromq.org/czmq3-0:zbeacon
  class Beacon
    include ::CZMQ::FFI

    # Used for {Beacon} errors.
    class Error < RuntimeError; end

    # function pointer to the `zbeacon()` function
    ZBEACON_FPTR = ::CZMQ::FFI.ffi_libraries.each do |dl|
      fptr = dl.find_function("zbeacon")
      break fptr if fptr
    end

    def initialize
      @actor = Actor.new(ZBEACON_FPTR)
    end

    # @return [Actor] the actor behind this Beacon
    attr_reader :actor

    VERBOSE_CMD = "VERBOSE".freeze

    # Enable verbose logging of commands and activity.
    # @return [void]
    def verbose!
      Zstr.send(@actor, VERBOSE_CMD)
    end

    CONFIGURE_PIC = "si".freeze
    CONFIGURE_CMD = "CONFIGURE".freeze

    # @param port_number [Integer]
    # @return [String] hostname, which can be used as endpoint for incoming
    #   connections
    # @raise [Error] if the system doesn't support UDP broadcasts
    def configure(port_number)
      # TODO: provide Actor#send_picture (or better name, #sys_send)
      Zsock.send(@actor, CONFIGURE_PIC, CONFIGURE_CMD,
                              port_number)
      hostname = Zstr.recv(@actor)
      raise Error, "system doesn't support UDP broadcasts" if hostname.empty?
      return hostname
    end

    PUBLISH_PIC = "sbi".freeze
    PUBLISH_CMD = "PUBLISH".freeze
    MAX_BEACON_DATA = 255

    # Start broadcasting a beacon.
    # @param data [String] data to publish
    # @param interval [Integer] interval in msec
    # @raise [Error] if data is longer than {MAX_BEACON_DATA} bytes
    # @return [void]
    def publish(data, interval)
      raise Error, "data is too long" if data.bytesize > MAX_BEACON_DATA
      Zsock.send(@actor, PUBLISH_PIC, PUBLISH_CMD, data,
                              data.bytesize, interval)
    end

    SILENCE_CMD = "SILENCE".freeze

    # Stop broadcasting the beacon.
    # @return [void]
    def silence
      Zstr.sendx(@actor, SILENCE_CMD, nil)
    end

    SUBSCRIBE_PIC = "sb".freeze
    SUBSCRIBE_CMD = "SUBSCRIBE".freeze

    # Start listening to beacons from peers.
    # @param filter [String] do a prefix match on received beacons
    # @return [void]
    def subscribe(filter)
      Zsock.send(@actor, SUBSCRIBE_PIC, SUBSCRIBE_CMD, filter,
                              filter.bytesize)
    end

    # Just like {#subscribe}, but subscribe to all peer beacons.
    # @return [void]
    def listen
      Zsock.send(@actor, SUBSCRIBE_PIC, SUBSCRIBE_CMD, nil, 0)
    end

    UNSUBSCRIBE_CMD = "UNSUBSCRIBE".freeze

    # Stop listening to other peers.
    # @return [void]
    def unsubscribe
      Zstr.sendx(@actor, UNSUBSCRIBE_CMD, nil)
    end

    # Receive next beacon from a peer.
    # @return [Message] 2-frame message with ([ipaddr, data])
    def receive
      Message.receive_from(@actor)
    end
  end
end
