# enwrite

> What wild heart-histories seemed to lie enwritten<br/>
> Upon those crystalline, celestial spheres!
<p align="right">&mdash;Edgar Allan Poe</p>

Evernote-powered statically-generated blogs and websites.

Very early work-in-progress, more to come soon.

For now it produces output suitable for [Hugo](http://gohugo.io). You
need to have an existing Hugo install. Sample usage (for now you need
to get an Evernote authentication token at
https://sandbox.evernote.com/api/DeveloperToken.action:

    $ export EN_AUTH_TOKEN=xxxxxxxxx
    $ export RUBYLIB=./lib
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
        -h, --help                       Shows this help message
    
    $ ./enwrite.rb -n my_notebook -o /my/hugo/blog/
    
    $ ./enwrite.rb -s 'some search expression' -o /my/hugo/blog
