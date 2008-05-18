require 'stringio'

module YARD
  module Parser
    # Responsible for parsing a source file into the namespace
    class SourceParser 
      attr_reader :file

      def self.parse(content)
        new.parse(content)
      end

      def self.parse_string(content)
        new.parse(StringIO.new(content))
      end

      attr_accessor :namespace, :visibility, :scope, :owner

      def initialize
        @file = "<STDIN>"
        @namespace = YARD::Registry.root
        @visibility = :public
        @scope = :instance
        @owner = @namespace
      end

      ##
      # Creates a new SourceParser that parses a file and returns
      # analysis information about it.
      #
      # @param [String, TokenList, StatementList, #read] content the source file to parse
      def parse(content = __FILE__)
        case content
        when String
          @file = content
          statements = StatementList.new(IO.read(content))
        when TokenList
          statements = StatementList.new(content)
        when StatementList
          statements = content
        else
          if content.respond_to? :read
            statements = StatementList.new(content.read)
          else
            raise ArgumentError, "Invalid argument for SourceParser::parse: #{content.inspect}:#{content.class}"
          end
        end

        top_level_parse(statements)
      end

      private
        def top_level_parse(statements)
            statements.each do |stmt|
              find_handlers(stmt).each do |handler| 
                begin
                  handler.new(self, stmt).process
                rescue Handlers::UndocumentableError => undocerr
                  log.warn "in #{handler.to_s}: Undocumentable #{undocerr.message}"
                  log.warn "\tin file '#{file}':#{stmt.tokens.first.line_no}:\n\n" + stmt.inspect + "\n"
                rescue => e
                  log.error "Unhandled exception in #{handler.to_s}:"
                  log.error "  " + e.message
                  log.error "  in `#{file}`:#{stmt.tokens.first.line_no}:\n\n#{stmt.inspect}\n"
                  log.debug "Stack trace:" + e.backtrace[0..5].map {|x| "\n\t#{x}" }.join + "\n"
                end
              end
            end
        end

        def find_handlers(stmt)
          Handlers::Base.subclasses.find_all {|sub| sub.handles? stmt.tokens }
        end
    end
  end
end
