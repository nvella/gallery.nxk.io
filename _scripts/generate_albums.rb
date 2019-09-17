#
#  usage: ruby generate_album.rb album_collection_path jekyll_site_path
#  Generates the Jekyll files from an AlbumMan album
#  Check out AlbumMan at github.com/nvella/albumman
#

require 'yaml'

class AlbumsGenerator
  def initialize(album_collection_path, jekyll_site_path)
    @album_collection_path = album_collection_path
    @jekyll_site_path = jekyll_site_path
  end

  def jekyll_albums_col; File.join(@jekyll_site_path, '_albums'); end
  def jekyll_images_col; File.join(@jekyll_site_path, 'images'); end

  def run
    log "generate_albums..."
    log "Albums collection: #{@album_collection_path}"
    log "Jekyll site path: #{@jekyll_site_path}"

    cleanup

    Dir.entries(@album_collection_path).each do |album|
      next if album == '.' || album == '..'
      next if !Dir.exists?(File.join(@album_collection_path, album))
      do_album(album)
    end
  end

  def clear_dir(path)
    Dir.entries(path).select {|f| f != '.' && f != '..'}.each do |f|
      File.delete(File.join(path, f))
    end
  end

  def cleanup
    # Delete all albums
    clear_dir(jekyll_albums_col)

    # Delete all images
    clear_dir(jekyll_images_col)
  end

  def do_album(album_path)
    full_path = File.join(@album_collection_path, album_path)
    album_yml = File.join(full_path, 'album.yml')

    log "> '#{album_path}'"
    unless File.exists?(album_yml)
      sublog "No album.yml"
      return
    end

    # Parse album.yml
    album = YAML.load_file(album_yml)
    
    # Write album markdown
    album_md = {
      'id' => album['id'],
      'title' => album['title'],
      'layout' => 'album',
      'photos' => []
    }

    # Process photos
    album["photos"].select {|p| p["marked"]}.each do |photo|
      album_photo_md = {
        'file_name' => photo['file_name'],
        'title' => photo['title']
      }

      album_md['photos'].push(album_photo_md)
    end
    
    album_md_path = File.join(jekyll_albums_col, "#{album['id']}.md")
    File.open(album_md_path, 'w') { |file| file.write("#{YAML.dump(album_md).chomp}\n---\n\n#{album["description"]}") }
  end

  def log(msg)
    $stderr.puts "[#{Time.now}]> #{msg}"
  end

  def sublog(msg)
    log("  #{msg}")
  end
end

if ARGV.length < 2
  $stderr.puts "usage: ruby generate_album.rb album_collection_path jekyll_site_path"
  exit 1
end

AlbumsGenerator.new(ARGV[0], ARGV[1]).run