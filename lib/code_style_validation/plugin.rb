module Danger
  # This plugin uses code style checker (validator in the following) to look
  # for code style violations in added lines on the current MR / PR, and offers
  # inline patches.
  # The default validator is 'clang-format'. Only Objective-C files, with
  # extensions ".h", ".m", and ".mm" are checked.
  # It is possible to use other validators for other languages, e.g. 'yapf' for Python.
  #
  # @example Ensure that changes do not violate code style in Objective-C files
  #
  #          code_style_validation.check
  #
  # @example Ensure that changes do not violate code style in files with given extensions
  #
  #          code_style_validation.check file_extensions: ['.hpp', '.cpp']
  #
  # @example Ensure that changes do not violate code style in Python files with YAPF
  #
  #          code_style_validation.check validator: 'yapf',
  #                                      file_extensions: ['.py']
  #
  # @example Ensure that changes do not violate code style, ignoring Pods directory
  #
  #          code_style_validation.check ignore_file_patterns: [/^Pods\//]
  #
  # @see danger/danger
  # @tags code style, validation
  #
  class DangerCodeStyleValidation < Plugin
    VIOLATION_ERROR_MESSAGE = 'Code style violations detected.'.freeze

    # Validates the code style of changed & added files using a validator program.
    # Generates Markdown message with respective patches.
    #
    # @return [void]
    def check(config = {})
      defaults = {validator: 'clang-format', file_extensions: ['.h', '.m', '.mm'], ignore_file_patterns: []}
      config = defaults.merge(config)
      validator = *config[:validator]
      file_extensions = [*config[:file_extensions]]
      ignore_file_patterns = [*config[:ignore_file_patterns]]

      diff = git.added_files.concat git.modified_files
      offending_files, patches = resolve_changes(validator, diff)

      message = ''
      unless offending_files.empty?
        message = 'Code style violations detected in the following files:' + "\n"
        offending_files.each do |file_name|
          message += '* `' + file_name + "`\n\n"
        end
        message += 'Execute one of the following actions and commit again:' + "\n"
        message += '1. Run `%s` on the offending files' % validator + "\n"
        message += '2. Apply the suggested patches with `git apply patch`.' + "\n\n"
        message += patches.join("\n")
      end

      return if message.empty?
      fail VIOLATION_ERROR_MESSAGE
      markdown '### Code Style Check'
      markdown '---'
      markdown message
    end

    private

    def generate_patch(title, content)
      markup_patch = '#### ' + title + "\n"
      markup_patch += "```diff \n" + content + "\n``` \n"
      markup_patch
    end

    def resolve_changes(validator, changes)
      # Parse all patches from diff string

      offending_files = []
      patches = []

      changes.grep(/\.m|\.mm/).each do |file_name|
        format_command_array = [validator, file_name]
        #message(format_command_array.join(' '))

        # validator command for formatting JUST changed lines
        formatted = `#{format_command_array.join(' ')}`

        formatted_temp_file = Tempfile.new('temp-formatted')
        formatted_temp_file.write(formatted)
        formatted_temp_file.rewind

        diff_command_array = ['diff', '-u', '--label', file_name, file_name, '--label', file_name, formatted_temp_file.path]

        # Generate diff string between formatted and original strings
        diff = `#{diff_command_array.join(' ')}`
        formatted_temp_file.close
        formatted_temp_file.unlink

        # generate arrays with:
        # 1. Name of offending files
        # 2. Suggested patches, in Markdown format
        unless diff.empty?
          offending_files.push(file_name)
          patches.push(generate_patch(file_name, diff))
        end
      end

      return offending_files, patches
    end
  end
end
