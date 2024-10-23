# -*- coding: utf-8 -*-
# frozen_string_literal: false

require 'minitest/autorun'
require 'csv'
require 'tempfile'
require 'shellwords'

class TestFilter < Minitest::Test

  # Names and aliases for options.
  CliOptionNames = {
    # Input options.
    converters: %w[--converters],
    field_size_limit: %w[--field_size_limit],
    headers: %w[--headers],
    header_converters: %w[--header_converters],
    input_row_sep: %w[--input_row_sep --in_row_sep],
    input_col_sep: %w[--input_col_sep --in_col_sep],
    unconverted_fields: %w[--unconverted_fields],
    # Output options.
    output_row_sep: %w[--output_row_sep --out_row_sep],
    output_col_sep: %w[--output_col_sep --out_col_sep],
    # Input/output options.
    col_sep: %w[-c --col_sep],
    row_sep: %w[-r --row_sep],
    quote_char: %w[-q --quote_char],
  }

  class Option

    attr_accessor :sym, :cli_option_names, :api_argument_value, :cli_argument_value

    def initialize(sym = nil, api_argument_value = nil)
      self.sym = sym || :nil
      self.cli_option_names = CliOptionNames[self.sym]
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
  Rows = [
    %w[aaa bbb ccc],
    %w[ddd eee fff],
  ]

  def make_csv_s(rows: Rows, row_sep: RowSep, col_sep: ColSep)
    csv_rows = []
    rows.each do |cols|
      csv_rows.push(cols.join(col_sep))
    end
    csv_rows.push('')
    csv_rows.join(row_sep)
  end

  def zzz_cli_option_s(name, value)
    s = name
    s += " #{value}" unless value.nil?
  end

  def csv_filepath(act_in_s, dirpath, option_sym)
    filename = "#{option_sym}.csv"
    filepath = File.join(dirpath, filename)
    File.write(filepath, act_in_s)
    filepath
  end

  def execute_in_cli(filepath, cli_options_s = '')
    command = "cat #{filepath} | ruby bin/filter #{cli_options_s}"
    capture_subprocess_io do
      system(command)
    end
  end

  def get_act_values(filepath, cli_option_name, primary_option, options)
    cli_options = [{name: cli_option_name, value: primary_option.cli_argument_value}]
    options.each do |option|
      cli_options.push({name: option.cli_option_names.first, value: option.cli_argument_value})
    end
    cli_options_s = ''
    cli_options.each do |cli_option|
      cli_options_s += " #{cli_option[:name]}"
      value = cli_option[:value]
      cli_options_s += " #{Shellwords.escape(value)}" unless value.nil?
    end
    execute_in_cli(filepath, cli_options_s)
  end

  def get_exp_value(filepath, primary_option, options)
    api_options = {primary_option.sym => primary_option.api_argument_value}
    options.each do |option|
      api_options[option.sym] = option.api_argument_value
    end
    act_in_s = File.read(filepath)
    exp_out_s = get_via_api(act_in_s, **api_options)
    return exp_out_s
  end

  # Get and return actual values via CLI.
  def get_via_cli(test_method, option_name)
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
  def verify_cli(test_method, act_in_s, options)
    act_out_s = ''
    Dir.mktmpdir do |dirpath|
      primary_option = options.shift
      filepath = csv_filepath(act_in_s, dirpath, primary_option.sym)
      primary_option.cli_option_names.each do |cli_option_name|
        # Get expected output string (from API).
        exp_out_s = get_exp_value(filepath, primary_option, options)
        # Get actual output and error strings (from CLI).
        act_out_s, act_err_s = get_act_values(filepath, cli_option_name, primary_option, options)
        assert_empty(act_err_s, test_method)
        assert_equal(exp_out_s.strip, act_out_s.strip, test_method)
      end
    end
    act_out_s
  end

  # Invalid option.

  def test_invalid_option
    %w[-Z --ZZZ].each do |option_name|
      act_out_s, act_err_s = get_via_cli(__method__, option_name)
      assert_empty(act_out_s)
      assert_match(/OptionParser::InvalidOption/, act_err_s)
    end
  end

  # No options.

  def test_no_options
    act_in_s = make_csv_s
    act_out_s = get_via_api(act_in_s)
    assert_equal(act_in_s, act_out_s)
  end

  # General options

  def test_option_h
    %w[-h --help].each do |option_name|
      act_out_s, act_err_s = get_via_cli(__method__, option_name)
      assert_match(/Usage/, act_out_s)
      assert_empty(act_err_s)
    end
  end

  def test_option_v
    %w[-v --version].each do |option_name|
      act_out_s, act_err_s = get_via_cli(__method__, option_name)
      assert_match(/\d+\.\d+\.\d+/, act_out_s)
      assert_empty(act_err_s)
    end
  end

  # Input options.

  def zzz_test_option_converters
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
    field_size_limit = 20
    act_in_s = make_csv_s
    options = [
      Option.new(:field_size_limit, field_size_limit)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  def zzz_test_option_headers
    headers = nil
    act_in_s = make_csv_s
    options = [
      Option.new(:headers, headers)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  def zzz_test_option_header_converters
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
    unconverted_fields = nil
    act_in_s = make_csv_s
    options = [
      Option.new(:unconverted_fields, unconverted_fields)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  # Input/output options.

  def test_option_c
    col_sep = 'X'
    act_in_s = make_csv_s(col_sep: col_sep)
    options = [
      Option.new(:col_sep, col_sep)
    ]
    act_out_s = verify_cli(__method__, act_in_s, options)
    assert_equal(act_in_s, act_out_s)
  end

  def zzz_test_option_input_col_sep
    input_col_sep = 'X'
    act_in_s = make_csv_s(row_sep: input_col_sep)
    options = [
      Option.new(:input_col_sep, input_col_sep)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  def zzz_test_option_output_col_sep
    output_col_sep = 'X'
    act_in_s = make_csv_s(row_sep: output_col_sep)
    options = [
      Option.new(:input_col_sep, output_col_sep)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  def zzz_test_options_c_and_input_col_sep
    input_col_sep = 'X'
    col_sep = 'Y'
    act_in_s = make_csv_s(col_sep: input_col_sep)
    options = [
      Option.new(:input_col_sep, input_col_sep),
      Option.new(:col_sep, col_sep),
    ]
    verify_via_api(__method__, act_in_s, options)
    verify_via_api(__method__, act_in_s, options.reverse)
  end

  def zzz_test_options_c_and_output_col_sep
    col_sep = 'X'
    output_col_sep = 'Y'
    act_in_s = make_csv_s(col_sep: col_sep)
    options = [
      Option.new(:output_col_sep, output_col_sep),
      Option.new(:col_sep, col_sep),
    ]
    verify_via_api(__method__, act_in_s, options)
    verify_via_api(__method__, act_in_s, options.reverse)
  end

  def zzz_test_options_input_col_sep_and_output_col_sep
    input_col_sep = 'X'
    output_col_sep = 'Y'
    act_in_s = make_csv_s(col_sep: input_col_sep)
    options = [
      Option.new(:input_col_sep, input_col_sep),
      Option.new(:output_col_sep, output_col_sep),
    ]
    verify_via_api(__method__, act_in_s, options)
    verify_via_api(__method__, act_in_s, options.reverse)
  end

  def zzz_test_option_r
    row_sep = 'X'
    act_in_s = make_csv_s(row_sep: row_sep)
    options = [
      Option.new(:row_sep, row_sep)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  def zzz_test_option_input_row_sep
    input_row_sep = 'A'
    act_in_s = make_csv_s(row_sep: input_row_sep)
    options = [
      Option.new(:input_row_sep, input_row_sep)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  def zzz_test_option_output_row_sep
    output_row_sep = 'A'
    act_in_s = make_csv_s(row_sep: output_row_sep)
    options = [
      Option.new(:input_row_sep, output_row_sep)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  def zzz_test_options_r_and_input_row_sep
    input_row_sep = 'X'
    row_sep = 'Y'
    act_in_s = make_csv_s(row_sep: input_row_sep)
    options = [
      Option.new(:input_row_sep, input_row_sep),
      Option.new(:row_sep, row_sep),
    ]
    verify_via_api(__method__, act_in_s, options)
    verify_via_api(__method__, act_in_s, options.reverse)
  end

  def zzz_test_options_r_and_output_row_sep
    row_sep = 'X'
    output_row_sep = 'Y'
    act_in_s = make_csv_s(row_sep: row_sep)
    options = [
      Option.new(:output_row_sep, output_row_sep),
      Option.new(:row_sep, row_sep),
    ]
    verify_via_api(__method__, act_in_s, options)
    verify_via_api(__method__, act_in_s, options.reverse)
  end

  def zzz_test_options_input_row_sep_and_output_row_sep
    input_row_sep = 'X'
    output_row_sep = 'Y'
    act_in_s = make_csv_s(row_sep: input_row_sep)
    options = [
      Option.new(:input_row_sep, input_row_sep),
      Option.new(:output_row_sep, output_row_sep),
    ]
    verify_via_api(__method__, act_in_s, options)
    verify_via_api(__method__, act_in_s, options.reverse)
  end

  def zzz_test_option_q
    quote_char = "Z"
    rows = [
      ['foo', 0],
      ["ZbarZ", 1],
      ['"baz"', 2],
    ]
    act_in_s = make_csv_s(rows: rows)
    options = [
      Option.new(:quote_char, quote_char)
    ]
    verify_via_api(__method__, act_in_s, options)
  end

  # Make sure we can pass multiple options.
  def zzz_test_multiple_options
    row_sep = 'R'
    col_sep = 'C'
    act_in_s = make_csv_s(row_sep: row_sep, col_sep: col_sep)
    options = [
      Option.new(:row_sep, row_sep),
      Option.new(:col_sep, col_sep),
    ]
    verify_via_api(__method__, act_in_s, options)
  end

end
