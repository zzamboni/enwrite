# Enwrite [![Gem Version](https://badge.fury.io/rb/enwrite.svg)](http://badge.fury.io/rb/enwrite)

> What wild heart-histories seemed to lie enwritten<br/>
> Upon those crystalline, celestial spheres!
<p align="right">&mdash;Edgar Allan Poe</p>

Evernote-powered statically-generated blogs and websites.

Still work-in-progress but functional, more docs to come soon.

The first time you run it (or if you use the `--auth` flag afterward)
you will be asked to open an Evernote authentication page, and then to
provide the authentication code to Enwrite.

For now it produces output suitable for [Hugo](http://gohugo.io). You
need to have an existing Hugo install.

## Installation

    $ sudo gem install enwrite

Make sure you have Hugo installed:
http://gohugo.io/overview/installing/

## Getting started

Create a new Hugo site for testing:

    $ cd ~/tmp
    $ hugo new site my-hugo-blog
    $ mkdir my-hugo-blog/themes; git clone https://github.com/zyro/hyde-x.git my-hugo-blog/themes/hyde-x

Populate it with contents from Evernote:

    $ enwrite --help
    Enwrite v0.2.4
    
    Usage: /usr/local/bin/enwrite [options] (at least one of -n or -s has to be specified)
    
    Search options:
        -n, --notebook NOTEBOOK          Process notes from specified notebook.
        -t, --tag TAG                    Process only notes that have this tag
                                         within the given notebook.
            --remove-tags [t1,t2,t3]     List of tags to remove from output posts.
                                         If no argument given, defaults to --tag.
        -s, --search SEARCHEXP           Process notes that match given search
                                         expression. If specified, --notebook
                                         and --tag are ignored.
    Output options:
        -p, --output-plugin PLUGIN       Output plugin to use (Valid values: hugo)
        -o, --output-dir OUTDIR          Base dir of hugo output installation
            --rebuild-all                Process all notes that match the given
                                         conditions (normally only updated notes
                                         are processed)
    Other options:
            --auth [TOKEN]               Force Evernote reauthentication (will
                                         happen automatically if needed). Use
                                         TOKEN if given, otherwise get one
                                         interactively.
            --config-tag TAG             Specify tag to determine config notes
                                         (default: _enwrite_config)
        -v, --verbose                    Verbose mode
        -d, --debug                      Debug output mode
            --version                    Show version
        -h, --help                       Shows this help message

## Sample usage

Generate posts from all notes tagged `published` in notebook
`my_notebook`:

    $ enwrite -n my_notebook -t published -o ~/tmp/my-hugo-blog
    $ cd ~/tmp/my-hugo-blog
    $ hugo server --watch

Generate posts from all notes matching `some search expression`:

    $ enwrite -s 'some search expression' -o /tmp/my-hugo-blog

Images, audio and video are embedded in the generated posts (audio
and video are done using HTML5 `<audio>` and `<video>` tags). Other
file types are stored and linked to with their filename.

## Special tags

The following tags trigger special behavior if found within the
selected notes:

### Globally-recognized tags

- `page`: publish the note as a page instead of a blog post.
- `post` (or none): publish the note as a blog post. This is the
default.
- `markdown`: store the note as Markdown instead of HTML. Markdown
  notes can still contain images or other formatting, this will be left
  untouched inside the Markdown file.
- `_enwrite_config`: the contents of the note must be in YAML format
  and contain configuration parameters to Enwrite (more documentation
  about this will be written soon). For example, if you wanted blog
  posts to be stored in the Hugo `blog` category instead of `post`,
  you could include this:

  ```
  hugo:
      tag_to_type:
          default: blog/
          post: blog/
          page:
  ```

### Hugo-specific tags

The following tags are recognized by the Hugo output plugin (the only
one available at the moment):

- `_enwrite_files_hugo`: text in these notes is ignored, but any
  attachments are stored under the Hugo output directory. `.tar.gz`
  files will be unpacked under that directory, all others will be
  stored as-is. You can use this to have Hugo config files, themes,
  static contents or anything else automatically installed by Enwrite
  as well. Please note that any "files" notes *must also* be included
  in the selection criteria specified by `-n`, `-t` or `-s` (e.g. if
  you are using `-t published`, your files notes must also be tagged
  `published` or they will be ignored).

  Any text in files notes will be ignored, so you can use it to make
  it human-readable. For example, I have the following note in the
  notebook that powers http://zzamboni.org/new/, so I can start from a
  plain Hugo site and have it fully customized after running
  `enwrite`:
  
  ![Files note screenshot](https://www.evernote.com/shard/s2/sh/f1baa4dc-9e30-4c61-9f94-0014ba80a531/900eb250af52c9e5/res/96777fc2-8ac6-4d30-9943-e05014df5dc8/skitch.png)

- Any tags of the form `_foo=bar` are inserted into the frontmatter
  for the generated posts as field `foo` with value `bar`. This might
  be used to add information (e.g. a custom `slug`, specify `weight` for
  ordeing of pages, or any other field which may control the behavior or
  output produced.
  
## Other tags

All the special tags described above are removed from the post before
publishing (you can configure additional ones to remove with the
`--remove-tags` option). All other tags are passed through to the
produced posts. Of course, you could have some of those tags also
trigger special behavior within the output system. For example, my
[custom Hyde-X Hugo theme](https://github.com/zzamboni/new/tree/master/themes/hyde-x-zzamboni)
recognizes the following tags:

- `_home`: set this page as the default for the site.
- `_menu=main`: add this page to the top-level navigation menu.

## Shortcuts

Shortcuts are of the form `[shortcutname params]`. The following
shortcuts are currently recognized:

- Embed Youtube video by URL or ID. You can optionally specify `width`
  and `height`. All arguments must be enclosed in double quotes.

  ```
[youtube url="https://www.youtube.com/watch?v=dQw4w9WgXcQ"]
[youtube src="https://www.youtube.com/watch?v=dQw4w9WgXcQ"]
[youtube id="dQw4w9WgXcQ" width="640px" height="480px"]
  ```

- Embed gist.

  ```
[gist url="https://gist.github.com/zzamboni/843142d3f759e582fe8f"]
  ```

## Planned features/fixes

https://github.com/zzamboni/enwrite/labels/enhancement

## Bugs, feature requests, feedback or other issues?

Please open a
[Github issue](https://github.com/zzamboni/enwrite/issues).
