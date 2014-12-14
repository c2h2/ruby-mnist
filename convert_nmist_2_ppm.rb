#!/usr/bin/env ruby
=begin
Author: github.com/c2h2

get your data files from: http://yann.lecun.com/exdb/mnist/ 

Thanks for ruby bitmap code from: http://rosettacode.org/wiki/Bitmap

ubyte data structures from: data website.

TRAINING SET LABEL FILE (train-labels-idx1-ubyte):

[offset] [type]          [value]          [description] 
0000     32 bit integer  0x00000801(2049) magic number (MSB first) 
0004     32 bit integer  60000            number of items 
0008     unsigned byte   ??               label 
0009     unsigned byte   ??               label 
........ 
xxxx     unsigned byte   ??               label
The labels values are 0 to 9.

TRAINING SET IMAGE FILE (train-images-idx3-ubyte):

[offset] [type]          [value]          [description] 
0000     32 bit integer  0x00000803(2051) magic number 
0004     32 bit integer  60000            number of images 
0008     32 bit integer  28               number of rows 
0012     32 bit integer  28               number of columns 
0016     unsigned byte   ??               pixel 
0017     unsigned byte   ??               pixel 
........ 
xxxx     unsigned byte   ??               pixel

=end

require 'fileutils'

class RGBColour
  def initialize(red, green, blue)
    unless red.between?(0,255) and green.between?(0,255) and blue.between?(0,255)
      raise ArgumentError, "invalid RGB parameters: #{[red, green, blue].inspect}"
    end
    @red, @green, @blue = red, green, blue
  end
  attr_reader :red, :green, :blue
  alias_method :r, :red
  alias_method :g, :green
  alias_method :b, :blue
 
  RED   = RGBColour.new(255,0,0)
  GREEN = RGBColour.new(0,255,0)
  BLUE  = RGBColour.new(0,0,255)
  BLACK = RGBColour.new(0,0,0)
  WHITE = RGBColour.new(255,255,255)

  def values
    [@red, @green, @blue]
  end
end
 
class Pixmap
  def initialize(width, height)
    @width = width
    @height = height
    @data = fill(RGBColour::WHITE)
  end
  attr_reader :width, :height
 
  def fill(colour)
    @data = Array.new(@width) {Array.new(@height, colour)}
  end
 
  def validate_pixel(x,y)
    unless x.between?(0, @width-1) and y.between?(0, @height-1)
      raise ArgumentError, "requested pixel (#{x}, #{y}) is outside dimensions of this bitmap"
    end
  end
 
  def [](x,y)
    validate_pixel(x,y)
    @data[x][y]
  end
  alias_method :get_pixel, :[]
 
  def []=(x,y,colour)
    validate_pixel(x,y)
    @data[x][y] = colour
  end
  alias_method :set_pixel, :[]=
  
  def save(filename)
    File.open(filename, 'w') do |f|
      f.puts "P6", "#{@width} #{@height}", "255"
      f.binmode
      @height.times do |y|
        @width.times do |x|
          f.print @data[x][y].values.pack('C3')
        end
      end
    end
  end
  alias_method :write, :save
end

class String
  def b2s
    b2i.to_s
  end

  def b2i
    unpack("N").first
  end
end


def load_org_files
  images=File.read("train-images-idx3-ubyte")#.force_encoding("us-ascii")
  labels=File.binread("train-labels-idx1-ubyte")#.force_encoding("us-ascii")

  magic = labels[0..4]
  puts "Label Magic is = " + magic.b2s
  magic2 = images[0..4]
  puts "Image Magic is = " + magic2.b2s
  $num = labels[4..8].b2i
  puts "Total Labels = " + $num.to_s
  $num2 = images[4..8].b2i
  puts "Total Images = " + $num2.to_s
  $rows = images[8..12].b2i
  puts "Total Rows = " + $rows.to_s
  $cols = images[12..16].b2i
  puts "Total Cols = " + $cols.to_s

  $labels_bytes=labels.bytes[8..-1] 
  $images_bytes=images.bytes[16..-1]
  $pixels=$rows * $cols # number of pixels of a picture
end

def print_num
  $num.times do |i|
    pix0=i*$pixels
    pic = $images_bytes[pix0..(pix0+$pixels)] * " "
    puts "#{i}|#{$labels_bytes[i]}|#{pic}"
  end
end

def save_pic
  10.times{|i| FileUtils.mkdir_p "training_data/#{i}"} 
  $num.times do |i|
    fn="training_data/#{$labels_bytes[i]}/#{i}.ppm"
    pm = Pixmap.new($cols, $rows)
    $rows.times do |r|
      $cols.times do |c|
        color = $images_bytes[i * $pixels + c + r * $cols]
        pm.set_pixel(c, r, RGBColour.new(color, color, color))
      end
    end
    pm.save fn
    puts "#{fn} saved."
  end
end

load_org_files
#print_num #disable first hash if print pure digits to STDOUT
save_pic
