require 'rocketamf/pure/io_helpers'

module RocketAMF
  module Pure
    # Pure ruby deserializer
    #--
    # AMF0 deserializer, it switches over to AMF3 when it sees the switch flag
    class Deserializer
      def initialize
        @ref_cache = []
      end

      def deserialize(source, type=nil)
        source = StringIO.new(source) unless StringIO === source
        type = read_int8 source unless type
        case type
        when AMF0_NUMBER_MARKER
          read_number source
        when AMF0_BOOLEAN_MARKER
          read_boolean source
        when AMF0_STRING_MARKER
          read_string source
        when AMF0_OBJECT_MARKER
          read_object source
        when AMF0_NULL_MARKER
          nil
        when AMF0_UNDEFINED_MARKER
          nil
        when AMF0_REFERENCE_MARKER
          read_reference source
        when AMF0_HASH_MARKER
          read_hash source
        when AMF0_STRICT_ARRAY_MARKER
          read_array source
        when AMF0_DATE_MARKER
          read_date source
        when AMF0_LONG_STRING_MARKER
          read_string source, true
        when AMF0_UNSUPPORTED_MARKER
          nil
        when AMF0_XML_MARKER
          #read_xml source
        when AMF0_TYPED_OBJECT_MARKER
          read_typed_object source
        when AMF0_AMF3_MARKER
          # # Rails.logger.info("Loading AMF3Deserializer")
          # caller.grep(/rocket-amf/).each{|line|# Rails.logger.info(" "*20+line)}
          
          AMF3Deserializer.new.deserialize(source)
        else
          raise AMFError, "Invalid type: #{type}"
        end
      end

      private
      include RocketAMF::Pure::ReadIOHelpers

      def read_number source
        res = read_double source
        res.is_a?(Float)&&res.nan? ? nil : res # check for NaN and convert them to nil
      end

      def read_boolean source
        read_int8(source) != 0
      end

      def read_string source, long=false
        len = long ? read_word32_network(source) : read_word16_network(source)
        source.read(len)
      end

      def read_object source, add_to_ref_cache=true
        obj = {}
        @ref_cache << obj if add_to_ref_cache
        while true
          key = read_string source
          type = read_int8 source
          break if type == AMF0_OBJECT_END_MARKER
          obj[key.to_sym] = deserialize(source, type)
        end
        obj
      end

      def read_reference source
        index = read_word16_network(source)
        @ref_cache[index]
      end

      def read_hash source
        len = read_word32_network(source) # Read and ignore length

        # Read first pair
        key = read_string source
        type = read_int8 source
        return [] if type == AMF0_OBJECT_END_MARKER

        # We need to figure out whether this is a real hash, or whether some stupid serializer gave up
        if key.to_i.to_s == key
          # Array
          obj = []
          @ref_cache << obj

          obj[key.to_i] = deserialize(source, type)
          while true
            key = read_string source
            type = read_int8 source
            break if type == AMF0_OBJECT_END_MARKER
            obj[key.to_i] = deserialize(source, type)
          end
        else
          # Hash
          obj = {}
          @ref_cache << obj

          obj[key.to_sym] = deserialize(source, type)
          while true
            key = read_string source
            type = read_int8 source
            break if type == AMF0_OBJECT_END_MARKER
            obj[key.to_sym] = deserialize(source, type)
          end
        end
        obj
      end

      def read_array source
        len = read_word32_network(source)
        array = []
        @ref_cache << array

        0.upto(len - 1) do
          array << deserialize(source)
        end
        array
      end

      def read_date source
        seconds = read_double(source).to_f/1000
        time = Time.at(seconds)
        tz = read_word16_network(source) # Unused
        time
      end

      def read_typed_object source
        # Create object to add to ref cache
        class_name = read_string source
        obj = RocketAMF::ClassMapper.get_ruby_obj class_name
        # Rails.logger.info("read_typed_object source: #{source} class_name: #{class_name}, obj: #{obj.inspect}")
        @ref_cache << obj

        # Read object props
        props = read_object source, false

        # Populate object
        RocketAMF::ClassMapper.populate_ruby_obj obj, props, {}
        return obj
      end
    end

    # AMF3 implementation of deserializer, loaded automatically by the AMF0
    # deserializer when needed
    class AMF3Deserializer
      def initialize
        @string_cache = []
        @object_cache = []
        @trait_cache = []
      end

      def deserialize(source, type=nil)
        source = StringIO.new(source) unless StringIO === source
        type = read_int8 source unless type
        case type
        when AMF3_UNDEFINED_MARKER
          nil
        when AMF3_NULL_MARKER
          nil
        when AMF3_FALSE_MARKER
          false
        when AMF3_TRUE_MARKER
          true
        when AMF3_INTEGER_MARKER
          read_integer source
        when AMF3_DOUBLE_MARKER
          read_number source
        when AMF3_STRING_MARKER
          read_string source
        when AMF3_XML_DOC_MARKER
          #read_xml_string
        when AMF3_DATE_MARKER
          read_date source
        when AMF3_ARRAY_MARKER
          read_array source
        when AMF3_OBJECT_MARKER
          read_object source
        when AMF3_XML_MARKER
          #read_amf3_xml
        when AMF3_BYTE_ARRAY_MARKER
          read_amf3_byte_array source
        when AMF3_DICT_MARKER
          # AMF3 has a type for Dicts. This is _NOT_ found in the official documentation
          # as of May 6, 2010.
          # References
          # StackOverflow: http://stackoverflow.com/questions/1731946/does-flash-player-10-use-a-new-unreleased-amf-specification
          # Python impl: http://dev.pyamf.org/ticket/696
          read_dict source
        else
          raise AMFError, "Invalid type: #{type}"
        end
      end

      private
      include RocketAMF::Pure::ReadIOHelpers

      def read_integer source
        n = 0
        b = read_word8(source) || 0
        result = 0

        while ((b & 0x80) != 0 && n < 3)
          result = result << 7
          result = result | (b & 0x7f)
          b = read_word8(source) || 0
          n = n + 1
        end

        if (n < 3)
          result = result << 7
          result = result | b
        else
          #Use all 8 bits from the 4th byte
          result = result << 8
          result = result | b

          #Check if the integer should be negative
          if (result > MAX_INTEGER)
            result -= (1 << 29)
          end
        end
        result
      end

      def read_number source
        res = read_double source
        res.is_a?(Float)&&res.nan? ? nil : res # check for NaN and convert them to nil
      end

      def read_string source
        type = read_integer source
        isReference = (type & 0x01) == 0

        # puts("read_string is : " + (isReference ? "a ref" : "not a ref"))
        if isReference
          reference = type >> 1
          # puts("read_string reference: #{reference}; string_cache: #{@string_cache}")
          return @string_cache[reference]
        else
          length = type >> 1
          str = ""
          if length > 0
            str = source.read(length)
            @string_cache << str
          end
          # puts("read_string str: #{str}; string_cache: #{@string_cache}")
          return str
        end
      end

      def read_amf3_byte_array source
        type = read_integer source
        isReference = (type & 0x01) == 0

        if isReference
          reference = type >> 1
          return @object_cache[reference]
        else
          length = type >> 1
          obj = StringIO.new source.read(length)
          @object_cache << obj
          obj
        end
      end

      def read_array source
        
        type = read_integer source
        isReference = (type & 0x01) == 0

        if isReference
          reference = type >> 1
          return @object_cache[reference]
        else
          length = type >> 1
          propertyName = read_string source
          # Rails.logger.info("propertyName in read_array: #{propertyName}")
          
          if propertyName != ""
            array = {}
            @object_cache << array
            begin
              while(propertyName.length)
                value = deserialize(source)
                array[propertyName] = value
                propertyName = read_string source
              end
            rescue Exception => e #end of object exception, because propertyName.length will be non existent
            end
            0.upto(length - 1) do |i|
              array["" + i.to_s] = deserialize(source)
            end
          else
            array = []
            @object_cache << array
            0.upto(length - 1) do
              array << deserialize(source)
            end
          end
          array
        end
      end

      def read_object source
        type = read_integer source
        isReference = (type & 0x01) == 0

        if isReference
          reference = type >> 1
          # Rails.logger.info("object_cache in read_object: #{@object_cache.inspect}")
          
          return @object_cache[reference]
        else
          # Rails.logger.info("ain't no reference in read_object (type=#{type})")
          class_type = type >> 1
          class_is_reference = (class_type & 0x01) == 0

          if class_is_reference
            reference = class_type >> 1
            class_definition = @trait_cache[reference]
          else
            class_name = read_string source
            externalizable = (class_type & 0x02) != 0
            dynamic = (class_type & 0x04) != 0
            attribute_count = class_type >> 3

            class_attributes = []
            # Rails.logger.info("read_object class_name: #{class_name} externalizable: #{externalizable} dynamic: #{dynamic} attr_count: #{attribute_count}")
            attribute_count.times{class_attributes << read_string(source)} # Read class members

            # Rails.logger.info("read_object class_attributes: #{class_attributes.inspect}")
            class_definition = {"class_name" => class_name,
                                "members" => class_attributes,
                                "externalizable" => externalizable,
                                "dynamic" => dynamic}
            @trait_cache << class_definition
          end

          obj = RocketAMF::ClassMapper.get_ruby_obj class_definition["class_name"]
          # Rails.logger.info("read_object mapped_class: #{obj.inspect}")
          @object_cache << obj

          if class_definition['externalizable']
            obj.externalized_data = deserialize(source)
          else
            props = {}
            class_definition['members'].each do |key|
              # Rails.logger.info("read_object deserializing member: #{key}")
              # Rails.logger.info("read_object source pos: #{source.pos}")
              value = deserialize(source)
              props[key.to_sym] = value
              # Rails.logger.info("read_object deserialized member: #{key} as #{value.inspect}")
            end
            # Rails.logger.info("read_object deserialized member: 365")
            dynamic_props = nil
            if class_definition['dynamic']
              dynamic_props = {}
              while (key = read_string_source source) && key.length != 0  do # read next key
                # Rails.logger.info("read_object before deserialize key=#{key}")
                value = deserialize(source)
                # break if key == 'dict'
                # Rails.logger.info("read_object after deserialize key=#{key}; value=#{value}")
                dynamic_props[key.to_sym] = value
              end
              # Rails.logger.info("read_object dynamic object past while loop")
              
            end
            # Rails.logger.info("read_object at line 374")
            RocketAMF::ClassMapper.populate_ruby_obj obj, props, dynamic_props
            # Rails.logger.info("read_object at line 376")
          end
          # Rails.logger.info("read_object object: #{obj.inspect}")          
          obj
        end
      end
      
      def read_string_source source 
        # Rails.logger.info("read_string_source started #{source}")
        output = read_string source
        # Rails.logger.info("read_string_source output #{output}")
        
        return output
      end

      def read_dict source
        # puts("read_dict enter pos: #{source.pos}")
        type = read_integer source
        isReference = (type & 0x01) == 0
        # puts("read_dict type: #{type.inspect} is_ref: #{isReference}")
        return @object_cache[type >> 1] if isReference
        @object_cache << (dict = Flash::Utils::Dictionary.new)
        
        # puts("read_dict dict_size: #{type >> 1}")
        
        # TODO: Why are we skipping this and what does it mean?
        
        skip = read_integer source
        (type >> 1).times do
          key = deserialize(source)
          value = deserialize(source)
          # puts "read_dict key: #{key.inspect} value: #{value.inspect}"
          dict[key] =  value
        end
        
        dict
      end

      def read_date source
        type = read_integer source
        isReference = (type & 0x01) == 0
        if isReference
          reference = type >> 1
          return @object_cache[reference]
        else
          seconds = read_double(source).to_f/1000
          time = Time.at(seconds)
          @object_cache << time
          time
        end
      end
    end
  end
end