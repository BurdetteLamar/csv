# -*- coding: utf-8 -*-
# frozen_string_literal: false

require 'minitest/autorun'
require 'csv'
require 'tempfile'

class TestFilter < Minitest::Test

  CliOptionNames = {
    col_sep: %w[-c --col_sep],
    row_sep: %w[-r --row_sep],
    quote_char: %w[-q --quote_char],
    input_row_sep: %w[--input_row_sep --in_row_sep],
    input_col_sep: %w[--input_col_sep --in_col_sep],
    output_row_sep: %w[--output_row_sep --out_row_sep],
    output_col_sep: %w[--output_col_sep --out_col_sep],
  }

  class Option

    attr_accessor :sym, :cli_option_names, :argument_value

    def initialize(sym = nil, argument_value = nil)
      self.sym = sym || :nil
      self.argument_value = argument_value
      self.cli_option_names = CliOptionNames[self.sym]
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

  def cli_option_s(name, value)
    s = name
    s += " #{value}" unless value.nil?
  end

  def csv_filepath(csv_s, dirpath, option_sym)
    filename = "#{option_sym}.csv"
    filepath = File.join(dirpath, filename)
    File.write(filepath, csv_s)
    filepath
  end

  def get_act_values(filepath, cli_options)
    cli_options_s = ''
    cli_options.each do |cli_option|
      cli_options_s += " #{cli_option[:name]}"
      value = cli_option[:value]
      cli_options_s += " #{value}" unless value.nil?
    end
    command = "cat #{filepath} | ruby bin/filter #{cli_options_s}"
    act_out_s, act_err_s = capture_subprocess_io do
      system(command)
    end
    [act_out_s, act_err_s]
  end

  def get_exp_value(filepath, api_options)
    csv_s = File.read(filepath)
    filtered_s = ''
    CSV.filter(csv_s, filtered_s, **api_options) do |row|
    end
    return filtered_s
  end

  def verify_via_cli(test_method, option_name, exp_out_pat: '', exp_err_pat: '')
    Dir.mktmpdir do |dirpath|
      sym = option_name.to_sym
      filepath = csv_filepath('', dirpath, sym)
      command = "cat #{filepath} | ruby bin/filter #{option_name}"
      act_out_s, act_err_s = capture_subprocess_io do
        system(command)
      end
      assert_match(exp_out_pat, act_out_s, test_method)
      assert_match(exp_err_pat, act_err_s, test_method)
    end
  end

  def verify_via_api(test_method, csv_s, options = [])
    Dir.mktmpdir do |dirpath|
      if options.empty?
        filepath = csv_filepath(csv_s, dirpath, :no_options)
        act_out_s, act_err_s = get_act_values(filepath, {})
        assert_empty(act_err_s, test_method)
        exp_out_s = get_exp_value(filepath, {})
        assert_equal(exp_out_s, act_out_s, test_method)
      else
        primary_option = options.shift
        filepath = csv_filepath(csv_s, dirpath, primary_option.sym)
        primary_option.cli_option_names.each do |cli_option_name|
          cli_options = [{name: cli_option_name, value: primary_option.argument_value}]
          options.each do |option|
            cli_options.push({name: option.cli_option_names.first, value: option.argument_value})
          end
          act_out_s, act_err_s = get_act_values(filepath, cli_options)
          assert_empty(act_err_s, test_method)
          api_options = {primary_option.sym => primary_option.argument_value}
          options.each do |option|
            api_options[option.sym] = option.argument_value
          end
          exp_out_s = get_exp_value(filepath, api_options)
          assert_equal(exp_out_s, act_out_s, test_method)
        end
      end
    end
  end

  # General options.

  def test_no_options
    csv_s = make_csv_s
    verify_via_api(__method__, csv_s)
  end

  def test_option_h
    %w[-h --help].each do |option_name|
      verify_via_cli(__method__, option_name, exp_out_pat: /Usage/)
    end
  end

  def test_option_v
    %w[-v --version].each do |option_name|
      verify_via_cli(__method__, option_name, exp_out_pat: /\d+\.\d+\.\d+/)
    end
  end

  def test_invalid_option
    %w[-Z --ZZZ].each do |option_name|
      verify_via_cli(__method__, option_name, exp_err_pat: /OptionParser::InvalidOption/)
    end
  end

  # Input options.

  def test_option_input_col_sep
    input_col_sep = 'X'
    csv_s = make_csv_s(row_sep: input_col_sep)
    options = [
      Option.new(:input_col_sep, input_col_sep)
    ]
    verify_via_api(__method__, csv_s, options)
  end

  def test_option_input_row_sep
    input_row_sep = 'A'
    csv_s = make_csv_s(row_sep: input_row_sep)
    options = [
      Option.new(:input_row_sep, input_row_sep)
    ]
    verify_via_api(__method__, csv_s, options)
  end

  # Output options.

  def test_option_output_col_sep
    output_col_sep = 'X'
    csv_s = make_csv_s(row_sep: output_col_sep)
    options = [
      Option.new(:input_col_sep, output_col_sep)
    ]
    verify_via_api(__method__, csv_s, options)
  end

  def test_option_output_row_sep
    output_row_sep = 'A'
    csv_s = make_csv_s(row_sep: output_row_sep)
    options = [
      Option.new(:input_row_sep, output_row_sep)
    ]
    verify_via_api(__method__, csv_s, options)
  end

  # Input/output options.

  def test_option_c
    col_sep = 'X'
    csv_s = make_csv_s(col_sep: col_sep)
    options = [
      Option.new(:col_sep, col_sep)
    ]
    verify_via_api(__method__, csv_s, options)
  end

  def test_option_r
    row_sep = 'X'
    csv_s = make_csv_s(row_sep: row_sep)
    options = [
      Option.new(:row_sep, row_sep)
    ]
    verify_via_api(__method__, csv_s, options)
  end

  def test_option_q
    quote_char = "Z"
    rows = [
      %w[foo 0],
      %w['bar' 1],
      %w["baz", 2],
      %w[ZbatZ, 2],
    ]
    csv_s = make_csv_s(rows: rows)
    options = [
      Option.new(:quote_char, quote_char)
    ]
    verify_via_api(__method__, csv_s, options)
  end

  # Make sure we can pass multiple options.
  def test_multiple_options
    row_sep = 'X'
    col_sep = 'Y'
    quote_char = 'Z'
    csv_s = make_csv_s(row_sep: row_sep, col_sep: col_sep)
    options = [
      Option.new(:row_sep, row_sep),
      Option.new(:col_sep, col_sep),
      Option.new(:quote_char, quote_char),
    ]
    verify_via_api(__method__, csv_s, options)
  end

end
