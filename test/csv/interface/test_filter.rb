# frozen_string_literal: false

require_relative "../helper"

class TestCSVInterfaceReadWrite < Test::Unit::TestCase
  extend DifferentOFS

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

  def do_test(csv_s, exp_out_pat: '', options: {})
    options_s = ''
    options.each_pair do |name, value|
      option_s = name
      option_s += " #{value}" unless value.nil?
      options_s += ' ' + option_s
    end
    CSV.filter(csv_s, )
    # Dir.mktmpdir do |dirpath|
    #   filepath = File.join(dirpath, 't.csv')
    #   File.write(filepath, csv_s)
    #   command = "cat #{filepath} | ruby bin/filter #{options_s}"
    #   act_out_s, act_err_s = capture_subprocess_io do
    #     system(command)
    #   end
    #   assert_match(exp_err_pat, act_err_s, caller[2])
    #   assert_match(exp_out_pat, act_out_s, caller[2])
    # end
  end


  #   def test_filter
#     input = <<-CSV.freeze
# 1;2;3
# 4;5
#     CSV
#     output = ""
#     CSV.filter(input, output,
#                in_col_sep: ";",
#                out_col_sep: ",",
#                converters: :all) do |row|
#       row.map! {|n| n * 2}
#       row << "Added\r"
#     end
#     assert_equal(<<-CSV, output)
# 2,4,6,"Added\r"
# 8,10,"Added\r"
#     CSV
#   end
#
#   def test_filter_headers_true
#     input = <<-CSV.freeze
# Name,Value
# foo,0
# bar,1
# baz,2
#     CSV
#     output = ""
#     CSV.filter(input, output, headers: true) do |row|
#       row[0] += "X"
#       row[1] = row[1].to_i + 1
#     end
#     assert_equal(<<-CSV, output)
# fooX,1
# barX,2
# bazX,3
#     CSV
#   end
#
#   def test_filter_headers_true_write_headers
#     input = <<-CSV.freeze
# Name,Value
# foo,0
# bar,1
# baz,2
#     CSV
#     output = ""
#     CSV.filter(input, output, headers: true, out_write_headers: true) do |row|
#       if row.is_a?(Array)
#         row[0] += "X"
#         row[1] += "Y"
#       else
#         row[0] += "X"
#         row[1] = row[1].to_i + 1
#       end
#     end
#     assert_equal(<<-CSV, output)
# NameX,ValueY
# fooX,1
# barX,2
# bazX,3
#     CSV
#   end
#
#   def test_filter_headers_array_write_headers
#     input = <<-CSV.freeze
# foo,0
# bar,1
# baz,2
#     CSV
#     output = ""
#     CSV.filter(input, output,
#                headers: ["Name", "Value"],
#                out_write_headers: true) do |row|
#       row[0] += "X"
#       row[1] = row[1].to_i + 1
#     end
#     assert_equal(<<-CSV, output)
# Name,Value
# fooX,1
# barX,2
# bazX,3
#     CSV
#   end
#
#   def test_instance_same
#     data = ""
#     assert_equal(CSV.instance(data, col_sep: ";").object_id,
#                  CSV.instance(data, col_sep: ";").object_id)
#   end
#
#   def test_instance_append
#     output = ""
#     CSV.instance(output, col_sep: ";") << ["a", "b", "c"]
#     assert_equal(<<-CSV, output)
# a;b;c
#     CSV
#     CSV.instance(output, col_sep: ";") << [1, 2, 3]
#     assert_equal(<<-CSV, output)
# a;b;c
# 1;2;3
#     CSV
#   end
#
#   def test_instance_shortcut
#     assert_equal(CSV.instance,
#                  CSV {|csv| csv})
#   end
#
#   def test_instance_shortcut_with_io
#     io = StringIO.new
#     from_instance = CSV.instance(io, col_sep: ";") { |csv| csv << ["a", "b", "c"] }
#     from_shortcut = CSV(io, col_sep: ";") { |csv| csv << ["e", "f", "g"] }
#
#     assert_equal(from_instance, from_shortcut)
#     assert_equal(from_instance.string, "a;b;c\ne;f;g\n")
#   end
end
