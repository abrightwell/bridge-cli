require "log"

module CB
  # Action is the base class for all actions performed by `cb`.
  abstract class Action
    Log   = ::Log.for("Action")
    Error = Program::Error

    property input : IO
    property output : IO

    def initialize(@input = STDIN, @output = STDOUT)
    end

    def call
      Log.info { "calling #{self.class}" }
      run
    end

    macro eid_setter(property, description = nil)
      property {{property}} : String?

      def {{property}}=(str : String)
        raise_arg_error {{description || property.stringify.gsub(/_/, " ")}}, str unless str =~ EID_PATTERN
        @{{property}} = str
      end
    end

    macro cluster_identifier_setter(property)
      property {{property}} : Hash(Symbol, Identifier) = Hash(Symbol, Identifier).new

      def {{property}}=(str : String)
        raise Program::Error.new "invalid cluster identifier" if str.empty?

        parts = str.split '/'

        @{{property}}[:team] =  Identifier.new(parts.shift) unless parts.size == 1
        @{{property}}[:cluster] = Identifier.new(parts.shift)
      end
    end

    macro identifier_setter(property)
      property {{property}} : Identifier?

      def {{property}}=(str : String)
        @{{property}} = Identifier.new(str)
      end
    end

    macro format_setter(property)
      property {{property}} : Format = Format::Default

      def {{property}}=(str : String)
        @{{property}} = Format.parse(str)
      end
    end

    macro role_setter(property)
      property {{property}} : Role = Role.new

      def {{property}}=(str : String)
        @{{property}} = Role.new str
      end
    end

    macro role_setter?(property)
      property {{property}} : Role?

      def {{property}}=(str : String)
        @{{property}} = Role.new str
      end
    end

    # For simple identifiers such as region names, or plan names where we
    # expect only lowercase, numbers, and -
    macro ident_setter(property)
      property {{property}} : String?

      def {{property}}=(str : String)
        raise_arg_error {{property.stringify}}, str unless str =~ IDENT_PATTERN
        @{{property}} = str
      end
    end

    # Non-nilable name setter. Used for name associated with API resources.
    macro name_setter(property)
      property {{property}} : String = ""

      def {{property}}=(str : String)
        raise_arg_error {{property.stringify}}, str unless str =~ API_NAME_PATTERN
        @{{property}} = str
      end
    end

    # Nilable name setter. Used for name associated with API resources.
    macro name_setter?(property)
      property {{property}} : String?

      def {{property}}=(str : String)
        raise_arg_error {{property.stringify}}, str unless str =~ API_NAME_PATTERN
        @{{property}} = str
      end
    end

    macro i32_setter(property)
      property {{property}} : Int32?

      def {{property}}=(str : String)
        self.{{property}} = str.to_i(base: 10, whitespace: true, underscore: true, prefix: false, strict: true, leading_zero_is_octal: false)
      rescue ArgumentError
        raise_arg_error {{property.stringify}}, str
      end
    end

    macro time_setter(property)
      property {{property}} : Time?

      def {{property}}=(str : String)
        self.{{property}} = Time.parse_rfc3339(str)
      rescue Time::Format::Error
        raise_arg_error "#{{{property.stringify}}} must be in rfc3339 format, e.g. 2022-01-01T00:00:00Z", str
      end
    end

    # Note: unlike the other macros, this one does not create a nilable boolean,
    # and instead creates one that defaults to false
    macro bool_setter(property)
      property {{property}} : Bool = false

      def {{property}}=(str : String)
        case str.downcase
        when "true"
          self.{{property}} = true
        when "false"
          self.{{property}} = false
        else
          raise_arg_error {{property.stringify}}, str
        end
      end
    end

    # Nilable boolean setter. This is useful for fields where nil can have a
    # meaningful value beyond being falesy.
    macro bool_setter?(property)
      property {{property}} : Bool?

      def {{property}}=(str : String)
        case str.downcase
        when "true"
          self.{{property}} = true
        when "false"
          self.{{property}} = false
        else
          raise_arg_error {{property.stringify}}, str
        end
      end
    end

    private def raise_arg_error(field, value)
      raise Error.new "Invalid #{field.colorize.bold}: '#{value.to_s.colorize.red}'"
    end

    private def check_required_args
      missing = [] of String
      yield missing
      unless missing.empty?
        s = missing.size > 1 ? "s" : ""
        raise Error.new "Missing required argument#{s}: #{missing.map(&.colorize.red).join(", ")}"
      end
      true
    end

    private def confirm_action(action, type, name)
      output << "About to #{action.colorize.t_warn} #{type} #{name.colorize.t_name}.\n"
      output << "  Type the #{type}'s name to confirm: "
      response = input.gets

      raise Error.new "Response did not match, did not #{action} #{type}." unless response == name
    end

    # Format floats such that if there are no significant digits to the right of
    # the decimal that it will simply format it as if it were an integer.
    # Effectively this is just simply truncating the formatted value.
    #
    # Example:
    #   format(1.0) -> 1
    #   format(1.1) -> 1.1
    private def format(value : Float)
      value.to_i == value ? value.format(decimal_places: 0) : value.format
    end
  end

  # APIAction performs some action utilizing the API.
  abstract class APIAction < Action
    property client : Client

    def initialize(@client, @input = STDIN, @output = STDOUT)
    end

    abstract def run

    private def print_team_slash_cluster(c)
      team_name = team_name_for_cluster c
      output << team_name << "/" if team_name
      output << c.name.colorize.t_name << "\n"
      team_name
    end

    private def team_name_for_cluster(c)
      team = client.get_team c.team_id
      team.name.colorize.t_alt
    end
  end
end
