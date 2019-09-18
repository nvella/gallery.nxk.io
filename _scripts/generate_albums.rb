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
  def jekyll_photos_col; File.join(@jekyll_site_path, '_photos'); end
  def jekyll_images_dir; File.join(@jekyll_site_path, 'images'); end

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

    # Delete all photo entries
    clear_dir(jekyll_photos_col)

    # Delete image symlinks and thumbs
    clear_dir(jekyll_images_dir)
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
    marked_photos = album['photos'].select {|p| p['marked']}
    album_md = {
      'album_id' => album['id'],
      'title' => album['title'],
      'layout' => 'album',
      'photos' => marked_photos.map {|p| p['id']}
    }

    album_md_path = File.join(jekyll_albums_col, "#{album['id']}.md")
    File.open(album_md_path, 'w') { |file| file.write("#{YAML.dump(album_md).chomp}\n---\n\n#{album["description"]}") }

    # Process photos
    marked_photos.each_with_index do |photo, index|
      prev_photo = index > 0 ? marked_photos[index - 1] : nil
      next_photo = index < marked_photos.length - 1 ? marked_photos[index + 1] : nil
  
      photo_md = {
        'photo_id' => photo['id'],
        'album_id' => album['id'],
        'file_name' => "#{photo['id']}#{File.extname(photo['file_name'])}",
        'title' => photo['title'],
        'next_photo_id' => next_photo&.dig('id'),
        'prev_photo_id' => prev_photo&.dig('id'),
        'number' => index + 1,
        'album_total' => marked_photos.length,
        'date' => photo['date'],
        'tags' => photo['tags'],
        'layout' => 'photo'
      }

      photo_md_path =  File.join(jekyll_photos_col, "#{photo['id']}.md")
      File.open(photo_md_path, 'w') { |file| file.write("#{YAML.dump(photo_md).chomp}\n---\n\n#{photo["description"]}") }

      # Symlink photo
      File.symlink(File.join(full_path, photo['file_name']), File.join(jekyll_images_dir, photo_md['file_name']))

      # Make thumbnail
      system "convert", \
          "-quality", "99", \
          "-format", "jpg", \
          "-thumbnail", "200x200", \
          File.join(full_path, photo['file_name']), \
          File.join(jekyll_images_dir, "thumb.#{photo_md['file_name']}")
    end
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