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

class Array
  def normalize
    xMin,xMax = self.minmax
    map {|x| x/ xMax }
  end

  def prob_array
    sum = inject(:+)
    map {|x| x/sum}
  end
end

class Trainer

  def initialize
    load_raw_files
    @nn_map        = Array.new(10)
    @nn_map_normal = Array.new(10)
    @nn_map_visual = Array.new(10)

    10.times do |i|
      @nn_map[i] = [0] * @pixels
      @nn_map_normal[i] = [0] * @pixels
      @nn_map_visual[i] = ' ' * @pixels
    end

  end

  def load_raw_files
    puts "Loading raw files."
    images=File.binread("train-images-idx3-ubyte")
    labels=File.binread("train-labels-idx1-ubyte")

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

  def save_nn_map
    File.open('nn_map.data', 'w') {|f| f.write(Marshal.dump(@nn_map)) }
  end

  def load_nn_map
    begin
      @nn_map=Marshal.load(File.read('nn_map.data'))
    rescue
      return nil
    end
    @nn_map
  end

  def train_1
    if !load_nn_map.nil?
      puts "Loaded data from save data file."
      return
    end

    puts "Parsing data from raw files."
    @total_num_data.times do |i|
      pm = Pixmap.new(@cols, @rows)
      @rows.times do |r|
        @cols.times do |c|
          color = @images_bytes[i * @pixels + c + r * @cols]
          @nn_map[@labels_bytes[i]][c + r * @rows] += color
        end
      end
      puts "#{i} done." if i % 5000 == 0
    end

    save_nn_map
  end

  def normalize_1
    puts "Normalizing values..."
    @nn_map.size.times do |fig|
      @pixels.times do |i|
        @nn_map_normal[fig][i]=@nn_map[fig][i] / 256.0 / @total_num_data.to_f
      end
    end

  end

  def visualize_nn_map
    @nn_map.size.times do |fig|
      @pixels.times do |i|
        if @nn_map_normal[fig][i] > 0.06
          @nn_map_visual[fig][i] = "*"
        elsif @nn_map_normal[fig][i] > 0.030
          @nn_map_visual[fig][i] = "+"
        elsif @nn_map_normal[fig][i] > 0.015
          @nn_map_visual[fig][i] = "."
        end
      end
    end

    @nn_map_visual.each do|fig|
      fig.scan(/.{28}/).each{|l| puts l}
    end
  end

  #accepts a new 2d graph (but encoded in 1d ruby array), values from 0-255
  #returns a probability array.
  def test_new_figure fig
    prob_arr=[0.0] * 10

    10.times do |i|
      fig.size.times do |j|
        abs_match_ratio = 1.0 - (@nn_map_normal[i][j] - fig[j]/256.0).abs
        prob_arr[i] += abs_match_ratio
      end
    end
    puts prob_arr.prob_array
    puts " "
    puts "Most likely = #{prob_arr.each_with_index.max[1]}"
    prob_arr
  end

end

t=Trainer.new
t.train_1
t.normalize_1
t.visualize_nn_map

t.test_new_figure [2] * 256