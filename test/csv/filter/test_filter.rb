# -*- coding: utf-8 -*-
# frozen_string_literal: false

require 'minitest/autorun'
require 'csv'
require 'tempfile'

class TestFilter < Minitest::Test

  def do_test(csv_s, exp_out_s, options = {}, exp_err_s = "")
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
    csv_s = "aaa,bbb,ccc\nddd,eee,fff"
    exp_out_s = csv_s + "\n"
    do_test(csv_s, exp_out_s)
  end

  RowSep = "\n"

  def test_option_r
    row_sep = 'X'
    [
      {'-r' => row_sep},
      {'--row_sep' => row_sep},
    ].each do |options_h|
      csv_s = "aaa,bbb,ccc#{row_sep}ddd,eee,fff"
      exp_out_s = "aaa,bbb,ccc#{row_sep}ddd,eee,fff#{row_sep}"
      do_test(csv_s, exp_out_s, options_h)
    end
  end

  def test_option_input_row_sep
    input_row_sep = 'X'
    options_h = {'--input_row_sep' => input_row_sep}
    csv_s = "aaa,bbb,ccc#{input_row_sep}ddd,eee,fff"
    exp_out_s = "aaa,bbb,ccc#{RowSep}ddd,eee,fff#{RowSep}"
    do_test(csv_s, exp_out_s, options_h)
  end

  def test_option_output_row_sep
    output_row_sep = 'X'
    options_h = {'--output_row_sep' => output_row_sep}
    csv_s = "aaa,bbb,ccc#{RowSep}ddd,eee,fff"
    exp_out_s = "aaa,bbb,ccc#{output_row_sep}ddd,eee,fff#{output_row_sep}"
    do_test(csv_s, exp_out_s, options_h)
  end

  def test_option_c
    col_sep = 'X'
    [
      {'-c' => col_sep},
      {'--col_sep' => col_sep},
    ].each do |options_h|
      csv_s = "aaa#{col_sep}bbb#{col_sep}ccc#{RowSep}ddd#{col_sep}eee#{col_sep}fff"
      exp_out_s = "aaa#{col_sep}bbb#{col_sep}ccc#{RowSep}ddd#{col_sep}eee#{col_sep}fff#{RowSep}"
      do_test(csv_s, exp_out_s, options_h)
    end
  end

end