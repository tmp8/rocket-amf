require 'rocketamf/pure/io_helpers'

module RocketAMF
  module Pure
    # Request deserialization module - provides a method that can be included into
    # RocketAMF::Request for deserializing the given stream.
    module Request
      def populate_from_stream stream
        stream = StringIO.new(stream) unless StringIO === stream

        # Initialize
        @amf_version = 0
        @headers = []
        @messages = []

        # Read AMF version
        @amf_version = read_word16_network stream

        # Read in headers
        header_count = read_word16_network stream
        0.upto(header_count-1) do
          name = stream.read(read_word16_network(stream))
          must_understand = read_int8(stream) != 0
          length = read_word32_network stream
          data = RocketAMF.deserialize stream
          @headers << RocketAMF::Header.new(name, must_understand, data)
        end

        # Read in messages
        message_count = read_word16_network stream
        0.upto(message_count-1) do
          target_uri = stream.read(read_word16_network(stream))
          response_uri = stream.read(read_word16_network(stream))
          length = read_word32_network stream
          data = RocketAMF.deserialize stream
          if data.is_a?(Array) && data.length == 1 && data[0].is_a?(::RocketAMF::Values::AbstractMessage)
            data = data[0]
          end
          @messages << RocketAMF::Message.new(target_uri, response_uri, data)
        end

        self
      end

      private
      include RocketAMF::Pure::ReadIOHelpers
    end

    # Response serialization module - provides a method that can be included into
    # RocketAMF::Response for deserializing the given stream.
    module Response
      def serialize
        stream = ""
        stream.encode("UTF-8") if stream.respond_to?(:encode)

        # Write version
        stream << pack_int16_network(@amf_version)

        # Write headers
        stream << pack_int16_network(@headers.length) # Header count
        @headers.each do |h|
          stream << pack_int16_network(h.name.length)
          stream << h.name
          stream << pack_int8(h.must_understand ? 1 : 0)
          stream << pack_word32_network(-1)
          stream << RocketAMF.serialize(h.data, 0)
        end

        # Write messages
        stream << pack_int16_network(@messages.length) # Message count
        @messages.each do |m|
          # # Rails.logger.info("Packing message")
          packed_target_uri = pack_int16_network(m.target_uri.length)
          packed_target_uri.force_encoding("UTF-8") if packed_target_uri.respond_to?(:force_encoding)
          
          stream << packed_target_uri
          stream << m.target_uri

          response_uri_length = pack_int16_network(m.response_uri.length)
          response_uri_length.force_encoding("UTF-8") if packed_target_uri.respond_to?(:force_encoding)
          stream << response_uri_length
          stream << m.response_uri

          packed_neg_one = pack_word32_network(-1)
          packed_neg_one.force_encoding("UTF-8") if packed_neg_one.respond_to?(:force_encoding)
          stream << packed_neg_one
          stream << AMF0_AMF3_MARKER if @amf_version == 3
          stream.encode("UTF-8") if stream.respond_to?(:encode)
          # # Rails.logger.info("stream #{stream.encoding} serialized #{RocketAMF.serialize(m.data, @amf_version).encoding}")
          stream << RocketAMF.serialize(m.data, @amf_version)
          # # Rails.logger.info("Packed message #{m}")
          # # Rails.logger.info("-"*20)
        end
        stream
      end

      private
      include RocketAMF::Pure::WriteIOHelpers
    end
  end
end