# Enwrite

> What wild heart-histories seemed to lie enwritten<br/>
> Upon those crystalline, celestial spheres!
<p align="right">&mdash;Edgar Allan Poe</p>

Evernote-powered statically-generated blogs and websites.

Very early work-in-progress, more to come soon.

The first time you run it (or if you use the `--auth` flag afterward)
you will be asked to open an Evernote authentication page, and then to
provided the authentication code to Enwrite.

For now it produces output suitable for [Hugo](http://gohugo.io). You
need to have an existing Hugo install. Sample usage:

    $ ./enwrite.rb -h
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
        -v, --verbose                    Verbose mode
        -h, --help                       Shows this help message
        
    $ ./enwrite.rb -n my_notebook -o /my/hugo/blog/
    
    $ ./enwrite.rb -s 'some search expression' -o /my/hugo/blog
