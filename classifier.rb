#!/usr/bin/env ruby

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


class Trainer

  def load_data
    images=File.read("train-images-idx3-ubyte")#.force_encoding("us-ascii")
    labels=File.binread("train-labels-idx1-ubyte")#.force_encoding("us-ascii")

    magic = labels[0..4]
    puts "Label Magic is = " + magic.b2s
    magic2 = images[0..4]
    puts "Image Magic is = " + magic2.b2s
    @total_num_data = labels[4..8].b2i
    puts "Total Labels = " + @total_num_data.to_s
    @num2 = images[4..8].b2i
    puts "Total Images = " + @num2.to_s
    @rows = images[8..12].b2i
    puts "Total Rows = " + @rows.to_s
    @cols = images[12..16].b2i
    puts "Total Cols = " + @cols.to_s

    @labels_bytes=labels.bytes[8..-1]
    @images_bytes=images.bytes[16..-1]
    @pixels=@rows * @cols # number of pixels of a picture

  end

  def save_data

  end

  def setup_nn
    @nn_map = Array.new(10)
    10.times{|i| @nn_map[i] = [0] * @pixels}

    @nn_map_normal= Array.new(10)
    10.times{|i| @nn_map_normal[i] = [0] * @pixels}

    @nn_map_visual= Array.new(10)
    10.times{|i| @nn_map_visual[i] = ' ' * @pixels}
  end

  def feed_1 figure, pos, val
    @nn_map[figure][pos] += val
  end


  def train_1
    @total_num_data.times do |i|
      pm = Pixmap.new(@cols, @rows)
      @rows.times do |r|
        @cols.times do |c|
          color = @images_bytes[i * @pixels + c + r * @cols]
          feed_1 @labels_bytes[i], c + r * @rows , color
        end
      end
      puts "#{i} done." if i % 1000 == 0
    end
  end

  def normalize_1
    puts "normalizing..."
    @nn_map.size.times do |fig|
      @pixels.times do |i|
        @nn_map_normal[fig][i]=@nn_map[fig][i] / 256.0 / @total_num_data.to_f
      end
    end

  end

  def visualize_nn_map
    @nn_map.size.times do |fig|
      @pixels.times do |i|
        if @nn_map_normal[fig][i] > 0.07
          @nn_map_visual[fig][i] = "*"
        elsif @nn_map_normal[fig][i] > 0.035
          @nn_map_visual[fig][i] = "-"
        elsif @nn_map_normal[fig][i] > 0.015
          @nn_map_visual[fig][i] = "."
        end
      end
    end

    @nn_map_visual.each do|fig|
      fig.scan(/.{28}/).each{|l| puts l}
    end
  end

end

t=Trainer.new
t.load_data
t.setup_nn
t.train_1
t.normalize_1
t.visualize_nn_map