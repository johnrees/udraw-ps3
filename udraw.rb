# brew install hidapi
# ruby udraw.rb

require 'ffi'
require 'mouse'

MOVE_MOUSE = false

module HidApi
  extend FFI::Library
  ffi_lib 'hidapi'

  attach_function :hid_open, [:int, :int, :pointer], :pointer
  attach_function :hid_write, [:pointer, :pointer, :int], :int
  attach_function :hid_read_timeout, [:pointer, :pointer, :int, :int], :int
  attach_function :hid_close, [:pointer], :void

  REPORT_SIZE = 0x1B # 64 bytes + 1 byte for report type
  def self.pad_to_report_size(bytes)
    (bytes+[0]*(REPORT_SIZE-bytes.size)).pack("C*")
  end
end

product_id = 0xcb17
vendor_id = 0x20d6
serial_number = nil
device = HidApi.hid_open( vendor_id, product_id, nil )

buffer = FFI::Buffer.new(:char, HidApi::REPORT_SIZE)
data = []

new_input = {
  buttons: nil,
  buttons2: nil,
  dpad: nil,
  accelerometer: { x: nil, y: nil, z: nil },
  tablet: { x: nil, y: nil, pressure: nil, device: nil }
}

input = nil

loop do
  res = HidApi.hid_read_timeout device, buffer, HidApi::REPORT_SIZE, 1000
  data = buffer.read_bytes(HidApi::REPORT_SIZE).unpack("C*")

  new_input[:buttons] = case data[0]
    when 0b00001 then "□"
    when 0b00010 then "✕"
    when 0b00100 then "○"
    when 0b01000 then "△"
  end

  new_input[:buttons2] = case data[1]
    when 0b10000 then "PS"
    when 0b00001 then "select"
    when 0b00010 then "start"
  end

  new_input[:dpad] = case data[2]
    when 0b00000000 then "UP"
    when 0b00000001 then "UP+RIGHT"
    when 0b00000010 then "RIGHT"
    when 0b00000011 then "DOWN+RIGHT"
    when 0b00000100 then "DOWN"
    when 0b00000101 then "DOWN+LEFT"
    when 0b00000110 then "LEFT"
    when 0b00000111 then "UP+LEFT"
  end

  # new_input[:accelerometer] = case data[14]
  #   when 0b10000 then "PS"
  #   when 0b00001 then "select"
  #   when 0b00010 then "start"
  # end
  # puts [data[19], data[20]].join(" > ")
  # puts [data[21], data[22]].join(" > ")
  # puts [data[23], data[24]].join(" > ")

  new_input[:tablet][:device] = if data[11] == 64
      "PEN"
    elsif data[11] == 128
      "TOUCH"
    elsif data[11] > 160
      "MULTITOUCH"
    else
      nil
    end


  new_input[:tablet][:pressure] = data[13] - 113

  x = (data[15] * 0b11111111) + data[17]
  new_input[:tablet][:x] = (x == 4080 ? nil : x)

  y = (data[16] * 0b11111111) + data[18]
  new_input[:tablet][:y] = (y == 4080 ? nil : y)

  if new_input != input
    input = Marshal.load( Marshal.dump(new_input) )
    p input
  end

  if MOVE_MOUSE && new_input[:tablet][:y] && new_input[:tablet][:x]
    Mouse.move_to [ new_input[:tablet][:x] ,  new_input[:tablet][:y] ], 0.00001
  end

end
