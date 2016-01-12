module CZTop
  # CZMQ poller, a trivial socket poller. This only supports polling for
  # reading, and only on (CZMQ) {Socket}s and {Actor}s (well, and "raw" ZMQ
  # sockets).
  #
  # @see http://api.zeromq.org/czmq3-0:zpoller
  class Poller
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods
    include ::CZMQ::FFI

    # Used for various {Poller} errors.
    class Error < RuntimeError; end

    # Initializes the Poller. At least one reader has to be given.
    # @param reader [Socket, Actor] socket to poll for input
    # @param readers [Socket, Actor] any additional sockets to poll for input
    def initialize(reader, *readers)
      @sockets = {}
      attach_ffi_delegate(Zpoller.new(reader, :pointer, nil))
      remember_socket(reader)
      readers.each { |r| add(r) }
    end

    # Adds another reader socket to the poller.
    # @param reader [Socket, Actor] socket to poll for input
    # @return [void]
    # @raise [Error] if this fails
    def add(reader)
      rc = ffi_delegate.add(reader)
      raise Error, "unable to add socket %p" % reader if rc == -1
      remember_socket(reader)
    end

    # Removes a reader socket from the poller.
    # @param reader [Socket, Actor] socket to remove
    # @return [void]
    # @raise [Error] if this fails (e.g. if socket wasn't registered in
    #   this poller)
    def remove(reader)
      rc = ffi_delegate.remove(reader)
      raise Error, "unable to remove socket %p" % reader if rc == -1
      forget_socket(reader)
    end

    # Wait and return the first socket that becomes readable.
    # @param timeout [Integer] how long to wait in ms, or 0 to avoid blocking,
    #   or -1 to wait indefinitely
    # @return [Socket, Actor]
    def wait(timeout = -1)
# //  Poll the registered readers for I/O, return first reader that has input.
# //  The reader will be a libzmq void * socket, or a zsock_t or zactor_t
# //  instance as specified in zpoller_new/zpoller_add. The timeout should be
# //  zero or greater, or -1 to wait indefinitely. Socket priority is defined
# //  by their order in the poll list. If you need a balanced poll, use the low
# //  level zmq_poll method directly. If the poll call was interrupted (SIGINT),
# //  or the ZMQ context was destroyed, or the timeout expired, returns NULL.
# //  You can test the actual exit condition by calling zpoller_expired () and
# //  zpoller_terminated (). The timeout is in msec.
# CZMQ_EXPORT void *
#     zpoller_wait (zpoller_t *self, int timeout);
      ptr = ffi_delegate.wait(timeout)
      if ptr.null?
        raise Interrupt if terminated?
        return nil if expired?
      end
      return socket_by_ptr(ptr)
    end

    # @return [Boolean]
    def expired?
# //  Return true if the last zpoller_wait () call ended because the timeout
# //  expired, without any error.
# CZMQ_EXPORT bool
#     zpoller_expired (zpoller_t *self);
      ffi_delegate.expired
    end

    # @return [Boolean]
    def terminated?
# //  Return true if the last zpoller_wait () call ended because the process
# //  was interrupted, or the parent context was destroyed.
# CZMQ_EXPORT bool
#     zpoller_terminated (zpoller_t *self);
      ffi_delegate.terminated
    end

    # @return [void]
    def ignore_interrupts
# //  Ignore zsys_interrupted flag in this poller. By default, a zpoller_wait will
# //  return immediately if detects zsys_interrupted is set to something other than
# //  zero. Calling zpoller_ignore_interrupts will supress this behavior.
# 
# CZMQ_EXPORT void
#     zpoller_ignore_interrupts(zpoller_t *self);
      ffi_delegate.ignore_interrupts
    end

    private

    # @return [void]
    def remember_socket(socket)
      @sockets[socket.to_ptr.to_i] = socket
    end
    # @return [void]
    def forget_socket(socket)
      @sockets.delete(socket.to_ptr.to_i)
    end
    def socket_by_ptr(ptr)
      @sockets[socket.to_ptr.to_i]
    end
  end
end
