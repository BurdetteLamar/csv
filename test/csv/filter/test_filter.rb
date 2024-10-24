# -*- coding: utf-8 -*-
# frozen_string_literal: false

require 'minitest/autorun'
require 'csv'
require 'tempfile'
require 'shellwords'

$TEST_DEBUG = false

class TestFilter < Minitest::Test

  # Names and aliases for options.
  CliOptionNames = {
    # Input options.
    converters: %w[--converters],
    field_size_limit: %w[--field_size_limit],
    headers: %w[--headers],
    header_converters: %w[--header_converters],
    input_col_sep: %w[--input_col_sep --in_col_sep],
    input_quote_char: %W[--input_quote_char --in_quote_char],
    input_row_sep: %w[--input_row_sep --in_row_sep],
    unconverted_fields: %w[--unconverted_fields],
    # Output options.
    force_quotes: %W[--force_quotes],
    output_col_sep: %w[--output_col_sep --out_col_sep],
    output_quote_char: %W[--output_quote_char --out_quote_char],
    output_row_sep: %w[--output_row_sep --out_row_sep],
    # Input/output options.
    col_sep: %w[-c --col_sep],
    row_sep: %w[-r --row_sep],
    quote_char: %w[-q --quote_char],
  }

  class Option

    attr_accessor :sym, :cli_option_names, :api_argument_value, :cli_argument_value

    def initialize(sym = nil, api_argument_value = nil)
      self.sym = sym || :nil
      self.cli_option_names = CliOptionNames.fetch(self.sym)
      self.api_argument_value = api_argument_value
      if api_argument_value.kind_of?(Array)
        cli_argument_a = []
        api_argument_value.each do |ele|
          cli_argument_a.push(ele.to_s)
        end
        self.cli_argument_value = cli_argument_a.join(',')
      else
        self.cli_argument_value = api_argument_value
      end
    end

  end

  RowSep = "\n"
  ColSep = ','
  QuoteChar = '"'
  Rows = [
    %w[aaa bbb ccc],
    %w[ddd eee fff],
  ]

  def expect_equal(exp_s, act_s)
    assert_equal(exp_s, act_s)
  end

  def doubt_equal(exp_s, act_s)
    refute_equal(exp_s, act_s)
  end

  def debug(label, value, newline: false)
    return unless $TEST_DEBUG
    print("\n") if newline
    printf("%15s: %s\n", label, value.inspect)
  end

  def get_test_name
    caller.each do |x|
      method_name = x.split(' ').last.gsub(/\W/, '')
      return method_name if method_name.start_with?('test')
    end
    raise RuntimeError.new('No test method name found.')
  end

  def do_test(debugging: false)
    unless debugging
      yield
      return
    end
    get_test_name
    $TEST_DEBUG = true
    test_name = get_test_name
    debug('BEGIN', test_name, newline: true)
    yield
    debug('END', test_name)
    $TEST_DEBUG = false
  end

  # Return CSV string generated from rows and options.
  def make_csv_s(rows: Rows, **options)
    csv_s = CSV.generate(**options) do|csv|
      rows.each do |row|
        csv << row
      end
    end
    csv_s
  end

  # Return filepath of file containing CSV data.
  def csv_filepath(act_in_s, dirpath, option_sym)
    filename = "#{option_sym}.csv"
    filepath = File.join(dirpath, filename)
    File.write(filepath, act_in_s)
    filepath
  end

  # Return stdout and stderr from CLI execution.
  def execute_in_cli(filepath, cli_options_s = '')
    debug('cli_options_s', cli_options_s)
    command = "cat #{filepath} | ruby bin/filter #{cli_options_s}"
    capture_subprocess_io do
      system(command)
    end
  end

  # Return CLI results for options.
  def cli_results_for_options(filepath, cli_option_name, primary_option, options)
    cli_options = [{name: cli_option_name, value: primary_option.cli_argument_value}]
    options.each do |option|
      cli_options.push({name: option.cli_option_names.first, value: option.cli_argument_value})
    end
    cli_options_s = ''
    cli_options.each do |cli_option|
      cli_options_s += " #{cli_option[:name]}"
      value = cli_option[:value]
      cli_options_s += " #{Shellwords.escape(value)}" unless [nil, true].include?(value)
    end
    execute_in_cli(filepath, cli_options_s)
  end

  # Return API result for options.
  def api_result(filepath, primary_option, options)
    api_options = {primary_option.sym => primary_option.api_argument_value}
    options.each do |option|
      api_options[option.sym] = option.api_argument_value
    end
    act_in_s = File.read(filepath)
    debug('api_options_h', api_options)
    exp_out_s = get_via_api(act_in_s, **api_options)
    return exp_out_s
  end

  # Return results for CLI-only option (or invalid option).
  def results_for_cli_option(option_name)
    act_out_s = ''
    act_err_s = ''
    Dir.mktmpdir do |dirpath|
      sym = option_name.to_sym
      filepath = csv_filepath('', dirpath, sym)
      act_out_s, act_err_s = execute_in_cli(filepath, option_name)
    end
    [act_out_s, act_err_s]
  end

  # Get and return the actual output from the API.
  def get_via_api(act_in_s, **api_options)
    act_out_s = ''
    CSV.filter(act_in_s, act_out_s, **api_options) {|row| }
    act_out_s
  end

  # Verify that the CLI behaves the same as the API.
  # Return the actual output.
  def verify_cli(act_in_s, options)
    options = options.dup # Don't modify caller's options.
    exp_out_s = ''
    act_out_s = ''
    act_err_s = ''
    saved_out_s = nil
    Dir.mktmpdir do |dirpath|
      primary_option = options.shift
      filepath = csv_filepath(act_in_s, dirpath, primary_option.sym)
      primary_option.cli_option_names.each do |cli_option_name|
        # Get expected output string (from API).
        exp_out_s = api_result(filepath, primary_option, options)
        # Get actual output and error strings (from CLI).
        act_out_s, act_err_s = cli_results_for_options(filepath, cli_option_name, primary_option, options)
        assert_empty(act_err_s)
        assert_equal(exp_out_s, act_out_s)
        # Output string should be the same for all iterations.
        saved_out_s = act_out_s if saved_out_s.nil?
        assert_equal(saved_out_s, act_out_s)
      end
    end
    debug('act_in_s', act_in_s)
    debug('exp_out_s', exp_out_s)
    debug('act_out_s', act_out_s)
    debug('act_err_s', act_err_s)
    act_out_s
  end

  # Invalid option.

  def test_invalid_option
    do_test(debugging: true) do
      %w[-Z --ZZZ].each do |option_name|
        act_out_s, act_err_s = results_for_cli_option(option_name)
        assert_empty(act_out_s)
        assert_match(/OptionParser::InvalidOption/, act_err_s)
      end
    end
  end

  # No options.

  def test_no_options
    do_test(debugging: false) do
      act_in_s = make_csv_s
      act_out_s = get_via_api(act_in_s)
      assert_equal(act_in_s, act_out_s)
    end
  end

  # General options

  def test_option_h
    do_test(debugging: false) do
      %w[-h --help].each do |option_name|
        act_out_s, act_err_s = results_for_cli_option(option_name)
        assert_match(/Usage/, act_out_s)
        assert_empty(act_err_s)
      end
    end
  end

  def test_option_v
    do_test(debugging: false) do
      %w[-v --version].each do |option_name|
        act_out_s, act_err_s = results_for_cli_option(option_name)
        assert_match(/\d+\.\d+\.\d+/, act_out_s)
        assert_empty(act_err_s)
      end
    end
  end

  # Input options.

  def zzz_test_option_converters
    debug('test_method', __method__)
    converters = %i[integer float]
    rows = [
      ['foo', 0],
      ['bar', 1.1],
    ]
    act_in_s = make_csv_s(rows: rows)
    options = [
      Option.new(:converters, converters)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  def zzz_test_option_field_size_limit
    debug('test_method', __method__)
    field_size_limit = 20
    act_in_s = make_csv_s
    options = [
      Option.new(:field_size_limit, field_size_limit)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  def zzz_test_option_headers
    debug('test_method', __method__)
    headers = nil
    act_in_s = make_csv_s
    options = [
      Option.new(:headers, headers)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  def zzz_test_option_header_converters
    debug('test_method', __method__)
    header_converters = %i[downcase symbol]
    rows = [
      ['Foo', 'Bar'],
      ['0', 1],
    ]
    act_in_s = make_csv_s(rows: rows)
    options = [
      Option.new(:headers, nil),
      Option.new(:header_converters, header_converters)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  def zzz_test_option_unconverted_fields
    debug('test_method', __method__)
    unconverted_fields = nil
    act_in_s = make_csv_s
    options = [
      Option.new(:unconverted_fields, unconverted_fields)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  # Input/output options.

  def test_option_c
    do_test(debugging: false) do
      col_sep = 'X'
      act_in_s = make_csv_s(col_sep: col_sep)
      options = [
        Option.new(:col_sep, col_sep)
      ]
      act_out_s = verify_cli(act_in_s, options)
      expect_equal(act_in_s, act_out_s)
    end
  end

  def test_option_input_col_sep
    do_test(debugging: false) do
      input_col_sep = 'X'
      act_in_s = make_csv_s(col_sep: input_col_sep)
      options = [
        Option.new(:input_col_sep, input_col_sep)
      ]
      act_out_s = verify_cli(act_in_s, options)
      doubt_equal(act_in_s, act_out_s)
    end
  end

  def test_option_output_col_sep
    do_test(debugging: false) do
      output_col_sep = 'X'
      act_in_s = make_csv_s
      options = [
        Option.new(:output_col_sep, output_col_sep)
      ]
      act_out_s = verify_cli(act_in_s, options)
      doubt_equal(act_in_s, act_out_s)
    end
  end

  def test_options_c_and_input_col_sep
    do_test(debugging: false) do
      debug('test_method', __method__)
      input_col_sep = 'X'
      col_sep = 'Y'
      act_in_s = make_csv_s(col_sep: input_col_sep)
      options = [
        Option.new(:input_col_sep, input_col_sep),
        Option.new(:col_sep, col_sep),
      ]
      # col_sep overrides input_col_sep.
      act_out_s = verify_cli(act_in_s, options)
      expect_equal(act_in_s, act_out_s)
      # input_col_sep overrides col_sep.
      act_out_s = verify_cli(act_in_s, options.reverse)
      doubt_equal(act_in_s, act_out_s)
    end
  end

  def test_options_c_and_output_col_sep
    do_test(debugging: false) do
      col_sep = 'X'
      output_col_sep = 'Y'
      act_in_s = make_csv_s(col_sep: col_sep)
      options = [
        Option.new(:output_col_sep, output_col_sep),
        Option.new(:col_sep, col_sep),
      ]
      # col_sep overrides output_col_sep.
      act_out_s = verify_cli(act_in_s, options)
      expect_equal(act_in_s, act_out_s)
      # output_col_sep overrides col_sep.
      act_out_s = verify_cli(act_in_s, options.reverse)
      doubt_equal(act_in_s, act_out_s)
    end
  end

  def test_options_input_col_sep_and_output_col_sep
    do_test(debugging: false) do
      input_col_sep = 'X'
      output_col_sep = 'Y'
      act_in_s = make_csv_s(col_sep: input_col_sep)
      options = [
        Option.new(:input_col_sep, input_col_sep),
        Option.new(:output_col_sep, output_col_sep),
      ]
      act_out_s = verify_cli(act_in_s, options)
      doubt_equal(act_in_s, act_out_s)
      act_out_s = verify_cli(act_in_s, options.reverse)
      doubt_equal(act_in_s, act_out_s)
    end
  end

  def test_option_r
    do_test(debugging: false) do
      row_sep = 'X'
      act_in_s = make_csv_s(row_sep: row_sep)
      options = [
        Option.new(:row_sep, row_sep)
      ]
      act_out_s = verify_cli(act_in_s, options)
      expect_equal(act_in_s, act_out_s)
    end
  end

  def test_option_input_row_sep
    do_test(debugging: false) do
      input_row_sep = 'A'
      act_in_s = make_csv_s(row_sep: input_row_sep)
      options = [
        Option.new(:input_row_sep, input_row_sep)
      ]
      act_out_s = verify_cli(act_in_s, options)
      doubt_equal(act_in_s, act_out_s)
    end
  end

  def test_option_output_row_sep
    do_test(debugging: false) do
      output_row_sep = 'A'
      act_in_s = make_csv_s(row_sep: output_row_sep)
      options = [
        Option.new(:input_row_sep, output_row_sep)
      ]
      act_out_s = verify_cli(act_in_s, options)
      doubt_equal(act_in_s, act_out_s)
    end
  end

  def test_options_r_and_input_row_sep
    do_test(debugging: false) do
      input_row_sep = 'X'
      row_sep = 'Y'
      act_in_s = make_csv_s(row_sep: input_row_sep)
      options = [
        Option.new(:input_row_sep, input_row_sep),
        Option.new(:row_sep, row_sep),
      ]
      # row_sep overrides input_row_sep.
      act_out_s = verify_cli(act_in_s, options)
      doubt_equal(act_in_s, act_out_s)
      # input_row_sep overrides row_sep.
      act_out_s = verify_cli(act_in_s, options.reverse)
      doubt_equal(act_in_s, act_out_s)
    end
  end

  def test_options_r_and_output_row_sep
    do_test(debugging: false) do
      row_sep = 'X'
      output_row_sep = 'Y'
      act_in_s = make_csv_s(row_sep: row_sep)
      options = [
        Option.new(:output_row_sep, output_row_sep),
        Option.new(:row_sep, row_sep),
      ]
      # row_sep overrides output_row_sep.
      act_out_s = verify_cli(act_in_s, options)
      expect_equal(act_in_s, act_out_s)
      # output_row_sep overrides row_sep.
      act_out_s = verify_cli(act_in_s, options.reverse)
      doubt_equal(act_in_s, act_out_s)
    end
  end

  def test_options_input_row_sep_and_output_row_sep
    do_test(debugging: false) do
      input_row_sep = 'X'
      output_row_sep = 'Y'
      act_in_s = make_csv_s(row_sep: input_row_sep)
      options = [
        Option.new(:input_row_sep, input_row_sep),
        Option.new(:output_row_sep, output_row_sep),
      ]
      # row_sep overrides output_row_sep.
      act_out_s = verify_cli(act_in_s, options)
      doubt_equal(act_in_s, act_out_s)
      # output_row_sep overrides row_sep.
      act_out_s = verify_cli(act_in_s, options.reverse)
      doubt_equal(act_in_s, act_out_s)
    end
  end

  def test_option_q
    do_test(debugging: false) do
      quote_char = "'"
      rows = [
        ['foo', 0],
        ["'bar'", 1],
        ['"baz"', 2],
      ]
      act_in_s = make_csv_s(rows: rows, quote_char: quote_char)
      options = [
        Option.new(:quote_char, quote_char)
      ]
      act_out_s = verify_cli(act_in_s, options)
      expect_equal(act_in_s, act_out_s)
    end
  end

  def test_option_input_quote_char
    do_test(debugging: false) do
      input_quote_char = "'"
      rows = [
        ['foo', 0],
        ["'bar'", 1],
        ['"baz"', 2],
      ]
      act_in_s = make_csv_s(rows: rows, quote_char: input_quote_char)
      options = [
        Option.new(:input_quote_char, input_quote_char)
      ]
      act_out_s = verify_cli(act_in_s, options)
      doubt_equal(act_in_s, act_out_s)
    end
  end

  def test_option_output_quote_char
    do_test(debugging: false) do
      output_quote_char = "X"
      rows = [
        ['foo', 0],
        ["'bar'", 1],
        ['"baz"', 2],
      ]
      act_in_s = make_csv_s(rows: rows)
      options = [
        Option.new(:output_quote_char, output_quote_char),
        Option.new(:force_quotes, true)
      ]
      act_out_s = verify_cli(act_in_s, options)
      doubt_equal(act_in_s, act_out_s)
    end
  end

end
