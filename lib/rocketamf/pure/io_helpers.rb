module RocketAMF
  module Pure
    module ReadIOHelpers #:nodoc:
      def read_int8 source
        # Rails.logger.info("read_int8 before read pos: #{source.pos}")
        read1 = source.read(1)

        unpacked = read1.unpack('c')
        
        # Rails.logger.info("read_int8 source:   #{source}")
        # Rails.logger.info("read_int8 read1:    #{read1.inspect}")
        # Rails.logger.info("read_int8 unpacked: #{unpacked.inspect}")
        # Rails.logger.info("read_int8 after read pos: #{source.pos}")
        # Rails.logger.info("-----------------------------------------------")
        # Rails.logger.info("read_int8 trace:")
        # caller.grep(/rocket-amf/).each{|line|# Rails.logger.info(" "*20+line)}

        unpacked.first
      end

      def read_word8 source
        # source.read(1).unpack('C').first        
        # Rails.logger.info("read_word8 before read pos: #{source.pos}")
        read1 = source.read(1)

        unpacked = read1.unpack('C')
        
        # Rails.logger.info("read_word8 source:   #{source}")
        # Rails.logger.info("read_word8 read1:    #{read1.inspect}")
        # Rails.logger.info("read_word8 unpacked: #{unpacked.inspect}")
        # Rails.logger.info("read_word8 after read pos: #{source.pos}")
        # Rails.logger.info("-----------------------------------------------")
        # Rails.logger.info("read_word8 trace:")
        # caller.grep(/rocket-amf/).each{|line|# Rails.logger.info(" "*20+line)}

        unpacked.first
      end

      def read_double source
        source.read(8).unpack('G').first
      end

      def read_word16_network source
        source.read(2).unpack('n').first
      end

      def read_int16_network source
        str = source.read(2)
        str.reverse! if byte_order_little? # swap bytes as native=little (and we want network)
        str.unpack('s').first
      end

      def read_word32_network source
        source.read(4).unpack('N').first
      end

      def byte_order
        if [0x12345678].pack("L") == "\x12\x34\x56\x78"
          :BigEndian
        else
          :LittleEndian
        end
      end

      def byte_order_little?
        (byte_order == :LittleEndian) ? true : false;
      end
    end

    module WriteIOHelpers #:nodoc:
      def pack_integer(integer)
        integer = integer & 0x1fffffff
        packed = if(integer < 0x80)
          [integer].pack('c')
        elsif(integer < 0x4000)
          [integer >> 7 & 0x7f | 0x80].pack('c')+
          [integer & 0x7f].pack('c')
        elsif(integer < 0x200000)
          [integer >> 14 & 0x7f | 0x80].pack('c') +
          [integer >> 7 & 0x7f | 0x80].pack('c') +
          [integer & 0x7f].pack('c')
        else
          [integer >> 22 & 0x7f | 0x80].pack('c')+
          [integer >> 15 & 0x7f | 0x80].pack('c')+
          [integer >> 8 & 0x7f | 0x80].pack('c')+
          [integer & 0xff].pack('c')
        end
        
        
        packed.force_encoding("UTF-8") if packed.respond_to?(:force_encoding)
        packed
      end

      def pack_double(double)
        packed = [double].pack('G')
        packed.force_encoding("UTF-8") if packed.respond_to?(:force_encoding)
        packed
      end

      def pack_int8(val)
        [val].pack('c')
      end

      def pack_int16_network(val)
        [val].pack('n')
      end

      def pack_word32_network(val)
        str = [val].pack('L')
        str.reverse! if byte_order_little? # swap bytes as native=little (and we want network)
        str
      end

      def byte_order
        if [0x12345678].pack("L") == "\x12\x34\x56\x78"
          :BigEndian
        else
          :LittleEndian
        end
      end

      def byte_order_little?
        (byte_order == :LittleEndian) ? true : false;
      end
    end
  end
end