# frozen_string_literal: true

module Karafka
  module Swarm
    # Pidfd Linux representation wrapped with Ruby for communication within Swarm
    # It is more stable than using `#pid` and `#ppid` + signals and cheaper
    class Pidfd
      include Helpers::Imports::Config.new(
        pidfd_open_syscall: %i[internal swarm pidfd_open_syscall],
        pidfd_signal_syscall: %i[internal swarm pidfd_signal_syscall]
      )

      extend FFI::Library
      ffi_lib 'c'

      # direct usage of this is only available since glibc 2.36, hence we use bindings and call it
      # directly via syscalls
      attach_function :fdpid_open, :syscall, %i[long int uint], :int
      attach_function :fdpid_signal, :syscall, %i[long int int pointer uint], :int

      # @param pid [Integer] pid of the node we want to work with
      def initialize(pid)
        @mutex = Mutex.new

        @pid = pid
        @pidfd = open(pid)
        @pidfd_io = IO.new(@pidfd)
      end

      # @return [Boolean] true if given process is alive, false if no longer
      def alive?
        @pidfd_select ||= [@pidfd_io]

        IO.select(@pidfd_select, nil, nil, 0).nil?
      end

      # Cleans the zombie process
      # @return [Boolean] true if collected, false if process is still alive
      def cleanup
        !::Process.waitpid(@pid, ::Process::WNOHANG).nil?
      rescue Errno::ECHILD
        true
      end

      # Sends given signal to the process using its pidfd
      # @param sig_name [String] signal name
      # @note It will not send signals to dead processes
      def signal(sig_name)
        @mutex.synchronize do
          # Never signal processes that are dead
          return unless alive?

          result = fdpid_signal(
            pidfd_signal_syscall,
            @pidfd,
            Signal.list.fetch(sig_name),
            nil,
            0
          )

          return if result.zero?

          raise Errors::PidfdOpenFailedError, result
        end
      end

      private

      # Opens a pidfd for the provided pid
      # @param pid [Integer]
      # @return [Integer] pidfd
      def open(pid)
        pidfd = fdpid_open(
          pidfd_open_syscall,
          pid,
          0
        )

        return pidfd if pidfd != -1

        raise Errors::PidfdSignalFailedError, pidfd
      end
    end
  end
end
