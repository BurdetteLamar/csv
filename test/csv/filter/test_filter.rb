# -*- coding: utf-8 -*-
# frozen_string_literal: false

require 'minitest/autorun'
require 'csv'
require 'tempfile'

class TestFilter < Minitest::Test

  RowSep = "\n"
  ColSep = ','
  Rows = [
    %w[aaa bbb ccc],
    %w[ddd eee fff],
  ]

  def make_csv_s(row_sep: RowSep, col_sep: ColSep)
    rows = []
    Rows.each do |cols|
      rows.push(cols.join(col_sep))
    end
    rows.push('')
    rows.join(row_sep)
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

  def test_option_r
    row_sep = 'X'
    %w[-r --row_sep].each do |option_name|
      options_h = {option_name => row_sep}
      csv_s = make_csv_s(row_sep: row_sep)
      exp_out_pat = csv_s
      do_test(csv_s, exp_out_pat: exp_out_pat, options: options_h)
    end
  end

  def test_option_input_row_sep
    input_row_sep = 'X'
    options_h = {'--input_row_sep' => input_row_sep}
    csv_s = make_csv_s(row_sep: input_row_sep)
    exp_out_pat = make_csv_s
    do_test(csv_s, exp_out_pat: exp_out_pat, options: options_h)
  end

  def test_option_output_row_sep
    output_row_sep = 'X'
    options_h = {'--output_row_sep' => output_row_sep}
    csv_s = make_csv_s
    exp_out_pat = make_csv_s(row_sep: output_row_sep)
    do_test(csv_s, exp_out_pat: exp_out_pat, options: options_h)
  end

  def test_option_c
    col_sep = 'X'
    %w[-c --col_sep].each do |option_name|
      options_h = {option_name => col_sep}
      csv_s = make_csv_s(col_sep: col_sep)
      exp_out_pat = csv_s
      do_test(csv_s, exp_out_pat: exp_out_pat, options: options_h)
    end
  end

  def test_option_input_col_sep
    input_col_sep = 'X'
    options_h = {'--input_col_sep' => input_col_sep}
    csv_s = make_csv_s(col_sep: input_col_sep)
    exp_out_pat = make_csv_s
    do_test(csv_s, exp_out_pat: exp_out_pat, options: options_h)
  end

  def test_option_output_col_sep
    output_col_sep = 'X'
    options_h = {'--output_col_sep' => output_col_sep}
    csv_s = make_csv_s
    exp_out_pat = make_csv_s(col_sep: output_col_sep)
    do_test(csv_s, exp_out_pat: exp_out_pat, options: options_h)
  end

  def test_option_invalid
    %w[-Z --ZZZ].each do |option_name|
      options_h = {option_name => nil}
      do_test('', exp_err_pat: 'InvalidOption', options: options_h)
    end
  end

end
