# Enwrite

> What wild heart-histories seemed to lie enwritten<br/>
> Upon those crystalline, celestial spheres!
<p align="right">&mdash;Edgar Allan Poe</p>

Evernote-powered statically-generated blogs and websites.

Very early work-in-progress, more to come soon.

The first time you run it (or if you use the `--auth` flag afterward)
you will be asked to open an Evernote authentication page, and then to
provide the authentication code to Enwrite.

For now it produces output suitable for [Hugo](http://gohugo.io). You
need to have an existing Hugo install.

## Getting started

Clone this repository:

    $ cd ~/tmp
    $ git clone https://github.com/zzamboni/enwrite

Install prerequisite gems using `bundler`:

    $ gem install bundler
    $ bundle install

Create a new Hugo site for testing (if you don't have one already):

    $ cd ~/tmp
    $ hugo new site my-hugo-blog
    $ mkdir my-hugo-blog/themes; git clone https://github.com/zyro/hyde-x.git my-hugo-blog/themes/hyde-x

Populate it with contents from Evernote:

    $ cd ~/tmp/enwrite
    $ ./enwrite.rb -h
    Enwrite v0.0.1
    
    Usage: ./enwrite.rb [options] (at least one of -n or -s has to be specified)
    
        -n, --notebook NOTEBOOK          Process notes from specified notebook.
        -t, --tag TAG                    Process only notes that have this tag
                                          within the given notebook.
        -s, --search SEARCHEXP           Process notes that match given search
                                          expression. If specified, --notebook
                                          and --tag are ignored.
        -o, --output-dir OUTDIR          Base dir of hugo output installation
            --remove-tags [t1,t2,t3]     List of tags to remove from output posts.
                                         If no argument given, defaults to --tag.
            --auth [TOKEN]               Force Evernote reauthentication (will happen automatically if needed).
                                         If TOKEN is given, use it, otherwise get one interactively.
            --rebuild-all                Process all notes that match the given conditions (normally only updated
                                         notes are processed)
        -v, --verbose                    Verbose mode
            --version                    Show version
        -h, --help                       Shows this help message
    
Generate posts from all notes tagged `published` in notebook
`my_notebook`:

    $ ./enwrite.rb -n my_notebook -t published -o ~/tmp/my-hugo-blog
    $ cd ~/tmp/my-hugo-blog
    $ hugo server --watch

Generate posts from all notes matching `some search expression`:

    $ ./enwrite.rb -s 'some search expression' -o /tmp/my-hugo-blog

For now it correctly embeds images in notes. Videos, audio and other
file types coming soon.

The following shortcuts are recognized:

Embed Youtube video by URL or ID. You can optionally specify `width`
and `height`. All arguments must be enclosed in double quotes.

    [youtube url="https://www.youtube.com/watch?v=dQw4w9WgXcQ"]
    [youtube src="https://www.youtube.com/watch?v=dQw4w9WgXcQ"]
    [youtube id="dQw4w9WgXcQ" width="640px" height="480px"]

Embed gist:

    [gist url="https://gist.github.com/zzamboni/843142d3f759e582fe8f"]
