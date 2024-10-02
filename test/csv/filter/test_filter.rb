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

  def make_csv_s(row_sep, col_sep, append_row_sep: false)
    rows = []
    Rows.each do |cols|
      rows.push(cols.join(col_sep))
    end
    s = rows.join(row_sep)
    s += row_sep if append_row_sep
    s
  end

  def do_test(csv_s, exp_out_s, options: {}, exp_err_s: '')
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
      assert_equal(exp_err_s, act_err_s, caller[2])
      assert_equal(exp_out_s, act_out_s, caller[2])
    end
  end

  def test_no_options
    csv_s = make_csv_s(RowSep, ColSep)
    exp_out_s = make_csv_s(RowSep, ColSep, append_row_sep: true)
    do_test(csv_s, exp_out_s)
  end

  def test_option_r
    row_sep = 'X'
    [
      {'-r' => row_sep},
      {'--row_sep' => row_sep},
    ].each do |options_h|
      csv_s = make_csv_s(row_sep, ColSep)
      exp_out_s = make_csv_s(row_sep, ColSep, append_row_sep: true)
      do_test(csv_s, exp_out_s, options: options_h)
    end
  end

  def test_option_input_row_sep
    input_row_sep = 'X'
    options_h = {'--input_row_sep' => input_row_sep}
    csv_s = make_csv_s(input_row_sep, ColSep)
    exp_out_s = make_csv_s(RowSep, ColSep, append_row_sep: true)
    do_test(csv_s, exp_out_s, options: options_h)
  end

  def test_option_output_row_sep
    output_row_sep = 'X'
    options_h = {'--output_row_sep' => output_row_sep}
    csv_s = make_csv_s(RowSep, ColSep)
    exp_out_s = make_csv_s(output_row_sep, ColSep, append_row_sep: true)
    do_test(csv_s, exp_out_s, options: options_h)
  end

  def test_option_c
    col_sep = 'X'
    [
      {'-c' => col_sep},
      {'--col_sep' => col_sep},
    ].each do |options_h|
      csv_s = make_csv_s(RowSep, col_sep)
      exp_out_s = make_csv_s(RowSep, col_sep, append_row_sep: true)
      do_test(csv_s, exp_out_s, options: options_h)
    end
  end

end