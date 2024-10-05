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
  }

  class Option

    attr_accessor :sym, :cli_option_names, :argument_value

    def initialize(sym, argument_value = nil)
      self.sym = sym
      self.argument_value = argument_value
      self.cli_option_names = CliOptionNames[sym]
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

  def cli_option(name, value)
    s = name
    s += " #{value}" unless value.nil?
  end

  def csv_filepath(csv_s, dirpath, option_sym)
    filename = "#{option_sym}.csv"
    filepath = File.join(dirpath, filename)
    File.write(filepath, csv_s)
    filepath
  end

  def do_verification(test_method, csv_s, option)
    Dir.mktmpdir do |dirpath|
      filepath = csv_filepath(csv_s, dirpath, option.sym)
      option.cli_option_names.each do |cli_option_name|
        cli_option = cli_option(cli_option_name, option.argument_value)
        # Make actual values.
        command = "cat #{filepath} | ruby bin/filter #{cli_option}"
        act_out_s, act_err_s = capture_subprocess_io do
          system(command)
        end
        # Verify $stderr.
        assert_empty(act_err_s, test_method)
        # Make expected output.
        open_options = {option.sym => option.argument_value}
        exp_out_s = CSV.open(filepath, **open_options) do |csv|
          rows = []
          csv.each do |row|
            rows << row.join(csv.col_sep)
          end
          rows << ''
          row_sep = csv.row_sep == "\r\n" ? "\n" : csv.row_sep
          rows.join(row_sep)
        end
        assert_equal(exp_out_s, act_out_s, test_method)
      end
    end
  end

  def do_test(csv_s, exp_out_pat: '', exp_err_pat: '', options: {})
    options_s = ''
    options.each_pair do |name, value|
      option_s = name
      option_s += " #{value}" unless value.nil?
      options_s += ' ' + option_s
    end
    Dir.mktmpdir do |dirpath|
      filepath = File.join(dirpath, 't.csv')
      File.write(filepath, csv_s)
      command = "cat #{filepath} | ruby bin/filter #{options_s}"
      act_out_s, act_err_s = capture_subprocess_io do
        system(command)
      end
      assert_match(exp_err_pat, act_err_s, caller[2])
      assert_match(exp_out_pat, act_out_s, caller[2])
    end
  end

  # General options.

  def test_no_options
    csv_s = make_csv_s
    exp_out_pat = csv_s
    do_test(csv_s, exp_out_pat: exp_out_pat)
  end

  def test_option_h
    %w[-h --help].each do |option_name|
      options_h = {option_name => nil}
      csv_s = make_csv_s
      exp_out_pat = /Usage/
      do_test(csv_s, exp_out_pat: exp_out_pat, options: options_h)
    end
  end

  def test_option_v
    %w[-v --version].each do |option_name|
      options_h = {option_name => nil}
      csv_s = make_csv_s
      exp_out_pat = /\d+\.\d+\.\d+/
      do_test(csv_s, exp_out_pat: exp_out_pat, options: options_h)
    end
  end

  def test_invalid_option
    %w[-Z --ZZZ].each do |option_name|
      options_h = {option_name => nil}
      do_test('', exp_err_pat: 'InvalidOption', options: options_h)
    end
  end

  # Input options.

  def test_option_input_col_sep
    input_col_sep = 'X'
    %w[--in_col_sep --input_col_sep].each do |option_name|
      options_h = {option_name => input_col_sep}
      csv_s = make_csv_s(col_sep: input_col_sep)
      exp_out_pat = make_csv_s
      do_test(csv_s, exp_out_pat: exp_out_pat, options: options_h)
    end
  end

  def test_option_input_row_sep
    input_row_sep = 'X'
    %w[--in_row_sep --input_row_sep].each do |option_name|
      options_h = {option_name => input_row_sep}
      csv_s = make_csv_s(row_sep: input_row_sep)
      exp_out_pat = make_csv_s
      do_test(csv_s, exp_out_pat: exp_out_pat, options: options_h)
    end
  end

  # Output options.

  def test_option_output_col_sep
    output_col_sep = 'X'
    %w[--out_col_sep --output_col_sep].each do |option_name|
      options_h = {option_name => output_col_sep}
      csv_s = make_csv_s
      exp_out_pat = make_csv_s(col_sep: output_col_sep)
      do_test(csv_s, exp_out_pat: exp_out_pat, options: options_h)
    end
  end

  def test_option_output_row_sep
    output_row_sep = 'X'
    %w[--out_row_sep --output_row_sep].each do |option_name|
      options_h = {option_name => output_row_sep}
      csv_s = make_csv_s
      exp_out_pat = make_csv_s(row_sep: output_row_sep)
      do_test(csv_s, exp_out_pat: exp_out_pat, options: options_h)
    end
  end

  # Input/output options.

  def test_option_c
    col_sep = 'X'
    csv_s = make_csv_s(col_sep: col_sep)
    option = Option.new(:col_sep, col_sep)
    do_verification(__method__, csv_s, option)
  end

  def test_option_r
    row_sep = 'X'
    csv_s = make_csv_s(row_sep: row_sep)
    option = Option.new(:row_sep, row_sep)
    do_verification(__method__, csv_s, option)
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
    option = Option.new(:quote_char, quote_char)
    do_verification(__method__, csv_s, option)
  end

end
