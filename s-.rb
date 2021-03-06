# Comments  -> ';' (!EndOfLine .)+ EndOfLine
# EndOfLine -> '\n' | '\r\n' | '\r'
# Hex       -> [0-9a-fA-F] | [1-9a-fA-F] [0-9a-fA-F]+ | [xX] [0-9a-fA-F]+
# Octal     -> 0[0-3][0-7][0-7] | [oO] [0-7]+
# Digit     -> [dD] [0-9]+
# Binary    -> [bB] [01]+ 
# Ident     -> [_a-zA-Z] [0-9a-zA-Z]+ | '[' [0-9a-zA-Z]+ ']'
module Sdec
  module_function
  def lex str
    str.lines.map { |l| scan l.chomp }.delete_if &:empty?
  end
  def scan line
    ans = []
    until line.empty?
      case
      when raw = line.slice!(/^\;.+$/)             then ans.push [:comment, raw]
      when raw = line.slice!(/^0[0-3][0-7][0-7]/)  then ans.push [:octal  , raw]
      when raw = line.slice!(/^[xX]\h+/)           then ans.push [:hex    , raw]
      when raw = line.slice!(/^[oO][0-7]+/)        then ans.push [:octal  , raw]
      when raw = line.slice!(/^[dD]\d+/)           then ans.push [:digit  , raw]
      when raw = line.slice!(/^[bB][01]+/)         then ans.push [:binary , raw]
      when raw = line.slice!(/^[1-9a-fA-F]\h+/)    then ans.push [:hex    , raw]
      when raw = line.slice!(/^\h/)                then ans.push [:hex    , raw]
      when raw = line.slice!(/^\w+|\[\w+\]/)       then ans.push [:ident  , raw]
      when raw = line.slice!(/^"([^"]|\\\")+"/)    then ans.push [:string , raw]
      when raw = line.slice!(/^\s+/)
      when raw = line.slice!(/^\S+/)               then ans.push [:raw    , raw]
      end
    end
    ans
  end
  def gas lexed
    sid = 0
    strings = []
    max_width = 0
    text = ".text\n.global _main\n_main:\n" + lexed.map do |l|
      comment = nil
      case l[0][0]
      when :comment
        ans = l[0][1].sub(';', '#')
      when :raw
        ans = l[0][1]
      else
        ans = '.byte ' + l.map do |type, raw|
          case type
          when :comment then comment = raw.sub(';', '#'); nil
          when :binary  then raw
          when :octal   then raw
          when :digit   then raw[1..-1]
          when :hex     then 'xX'.include?(raw[0]) ? "0#{raw}" : "0x#{raw}"
          when :ident   then raw[0] == '[' ? raw[1..-2] : raw
          when :string  then strings.push [sid += 1, raw]; "$s#{sid}"
          when :raw     then raw
          end
        end.compact.join(',')
        max_width = ans.length if max_width < ans.length
      end
      [ans, comment]
    end.map do |ans, comment|
      ans = format("%-#{max_width+1}s", ans)
      "  #{ans}#{comment}"
    end.join("\n")
    unless strings.empty?
      text += <<~EOD

        .data
        #{strings.map { |i, s| "  s#{i}: .asciz #{s}" }.join("\n")}
      EOD
    end
    text
  end
end

puts Sdec.gas Sdec.lex <<-EOF
; comments (use AT&T syntax because it's
; order is the same as machine code)
55                    ; push %ebp
89 0345               ; mov  %esp,%ebp
68 "Hello world\\n"   ; push str
e8 _puts              ; call _puts
83 0304 4             ; add  $4  ,%esp
31 0300               ; xor  %eax,%eax
83 0300 d42           ; add  $42 ,%eax
c9                    ; leave
c3                    ; ret
EOF
# =>
# .text
# .global _main
# _main:
#   # comments (use AT&T syntax because it's
#   # order is the same as machine code)
#   .byte 0x55          # push %ebp
#   .byte 0x89,0345     # mov  %esp,%ebp
#   .byte 0x68,$s1      # push str
#   .byte 0xe8,_puts    # call _puts
#   .byte 0x83,0304,0x4 # add  $4  ,%esp
#   .byte 0x31,0300     # xor  %eax,%eax
#   .byte 0x83,0300,42  # add  $42 ,%eax
#   .byte 0xc9          # leave
#   .byte 0xc3          # ret
# .data
#   s1: .asciz "Hello world\n"