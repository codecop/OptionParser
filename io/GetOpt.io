# -*- coding: utf-8 -*-

//metadoc GetOpt category API
/*metadoc GetOpt description
  This object helps scripts to parse the command line arguments in
  System args. It supports the same conventions as the Unix getopt()
  function. Most of the code is ported from the getopt module
  from Python's standart library.

  Usage example:
  
  <pre>
  Io> GetOpt with("a:b", list("abc=", "def")) getopt("-a1 -b --def --abc=@x7" split)
  ==> list(list("-a", "1"),
           list("-b", nil),
           list("--def", nil),
           list("--abc", "@x7")
      )
  </pre>

  Note, that GetOpt modifies provided argument list in place, thus, after the processing
  is finished, it will contain a list of non-option arguments.
  
  <pre>
  Io> args := "-a1 arg1 arg2" split
  ==> list("-a1", "arg1", "arg2")
  Io> GetOpt with("a:") getopt(args)
  ==> list(list("-a", "1"))
  Io> args
  ==> list("arg1", "arg2")
  </pre>
*/
GetOpt := Object clone do(
    init := method(
        self shortopts := ""
        self longopts  := list()
    )

    /*doc GetOpt with
        Creates a new option parser object with the arguments given. The
        first argument is a string of option letters that the script wants
        to recognize, with options that require an argument followed by a
        colon (i.e., the same format that Unix getopt() uses). The second
        argument, if specified, is a list of strings with the names of the
        long options which should be supported. The leading "--" characters
        should not be included in the option name. Options which require an
        argument should be followed by an equal sign ("=").

        Example:
        <pre>
        Io> GetOpt with("a:b", list("abc=", "def")
        ==>  GetOpt_0x8730e60:
          longopts         = list("abc=", "def")
          shortopts        = "a:b"
        </pre>

        Option parser defined above supports the following arguments:
        -a <value>, -b, --abc=<value>, --def.
    */
    with := method(shortopts, longopts,
        getopt := self clone
        if(shortopts isKindOf(Sequence), getopt shortopts = shortopts)
        if(longopts isKindOf(List), getopt longopts = longopts)
        getopt
    )

    /*doc GetOpt hasArg
        Wrapper method for for shortHasArg and longHasArg methods,
        executes the latter if given option isn't a single character,
        and the former if it is.
    */
    hasArg := method(opt,
        if(opt size == 1, shortHasArg(opt), longHasArg(opt))
    )

    /*doc GetOpt shortHasArg
        Performs a check if a given short option should have a value argument.
        Returns true if it does and else otherwise.

        Note: option should be present in GetOpt shortargs, or an exception
        will be raised.
    */
    shortHasArg := method(opt,
        idx := shortopts findSeq(opt)
        if(idx,
            next := shortopts at(idx + 1)
            next and next asCharacter == ":"
        ,
            Exception raise("Option -" .. opt .. " not recognized")
        )
    )

    /*doc GetOpt longHasArg
        Performs a check if a given long option should have a value argument.
        Returns a pair of form list(hasArgument, optionName), where hasArgument
        is a flag, representing check result, and optionName is a name of the
        option matched (in case only a part of the option name was provided).

        Note: option should be present in GetOpt longargs, or an exception will
        be raised.
    */
    longHasArg := method(opt,
        possibilities := longopts select(beginsWithSeq(opt))
        if(possibilities isEmpty,
            Exception raise("Option --" .. opt .. " not recoginzed")
        )

        if(opt in(possibilities), return list(false, opt))
        if((opt .. "=") in(possibilities), list(true, opt))

        if(possibilities size > 1,
            Exception raise("Option --" .. opt .. " is not a unique prefix")
        )

        opt = possibilities first
        if(opt endsWithSeq("="), list(true, opt beforeSeq("=")), list(false, opt))
    )

    /*doc GetOpt doShort
        Extracts an option-value pair from a given option string and argument
        list. Returns a pair of form list(optionName, optionValue), where the
        first element is option name, prefixed by a hypen and the second
        is option argument or nil, if the option takes no arguments.
    */
    doShort := method(optstring, args,
        # Due to a weird Sequence api, we can use removeAt(idx)
        # to get the option being removed, hopefully this will
        # changed in future.
        opt := optstring at(0) asCharacter
        optstring = optstring exSlice(1)

        if(shortHasArg(opt),
            # If an option requires an argument we extract it either
            # from the remaining part of the optstring or from the args
            # list. If the argument is not found, and exception
            # is raised.
            if(optstring isEmpty,
                if(args isEmpty,
                    Exception raise("Option -" .. opt .. " requires an argument")
                )
                value := args removeFirst
            ,
                value := optstring
            )
        )
        list("-" .. opt, getSlot("value"))
    )

    /*doc GetOpt doLong
        Works just like doShort, but for long arguments. 
    */
    doLong := method(opt, args,
        # Trying to extract option value from a given string.
        opt containsSeq("=") ifTrue(
            value := opt afterSeq("=")
            opt := opt beforeSeq("=")
        )

        data := longHasArg(opt)
        hasArg := data first
        opt := data last # Updating option name with the "guessed" value.

        if(hasArg,
            if(getSlot("value") isNil,
                if(args isEmpty,
                    Exception raise("Option --" .. opt .. " requires an argument")
                )
                value := args removeFirst
            )
        ,
            if(getSlot("value"),
                Exception raise("Option --" .. opt .. " must not have an argument")
            )
        )

        list("--" .. opt, getSlot("value"))
    )

    /*doc GetOpt getopt
        Parses command line options and parameter list from a given argument
        list (without the running program filename). Typically, this means
        "System args rest". Returns a list of (optionName, optionValue) pairs.
        Each pair returned has the option name as it's first element,
        prefixed by a hyphen (e.g. "-a"), and the option argument as its
        second element or nil, if the option has no argument. The options
        occur in the list in the same order in which they were found, thus
        allowing multiple occurrences for each option. Long an short options
        may be mixed. The processing stops once the first positional (non-option)
        argument is encountered.
    */
    getopt := method(args,
        # Since POSIX recommends, that options may be supplied in any order,
        # or appear multiple times. We can't use a Map to store the parsed
        # options.
        opts := list()

        while(args isEmpty not and args first beginsWithSeq("-") and args first != "-",
            if(args first == "--",
                # As stated by the getopt reference, the argument "--" terminates
                # all options; any following arguments are treated as non-option
                # arguments, even if they begin with a hyphen.
                args removeFirst
                break)

            opts append(
                if(args first beginsWithSeq("--"),
                    doLong(args first exSlice(2), args sliceInPlace(1))
                ,
                    doShort(args first exSlice(1), args sliceInPlace(1))
                )
            )
        )
        opts
    )

    /*doc GetOpt getoptGNU
        Works just like GetOpt getopt, except that GNU style scanning
        mode is used by default, which means that option and non-option
        arguments can be intermixed.

        If the first character of the predefined shortopts string is "+"
        or the environment variable POSIXLY_CORRECT is set, then option
        processing stops as soon as first non-option argument is encountered.
    */
    getoptGNU := method(args,
        opts := list()
        progArgs := list()

        # This behaviour was copied from Python's getopt module, no
        # evidence of the "+" flag being a common solution for disabling
        # GNU argument parsing were found.
        allOptionsFirst := if(shortopts beginsWithSeq("+"),
            shortopts = shortopts exSlice(1)
            true
        ,
            System getEnvironmentVariable("POSIXLY_CORRECT") isNil not
        )

        while(args isEmpty not,
            arg := args first # Processed argument.

            if(args first == "--",
                args removeFirst
                break
            )

            if(arg beginsWithSeq("--")) then(
                opts append(
                    doLong(arg exSlice(2), args sliceInPlace(1))
                )
            ) elseif(arg size > 1 and arg beginsWithSeq("-")) then(
                opts append(
                    doShort(arg exSlice(1), args sliceInPlace(1))
                )
            ) elseif(allOptionsFirst) then(
                break
            ) else(
                progArgs append(args removeFirst)
            )
        )
        # Kind of a dirty hack, populating the provided args list
        # with unparsed arguments.
        args appendSeq(progArgs)
        opts
    )
)

Object do(
    /*doc Object getopt
        Shortcut method, returns a list of arguments parsed with GetOpt's getopt().

        <pre>
        Object getopt(shortlist, longlist, args) -> opts
        Object getopt(shortlist, args) -> opts
        </pre>

        Usage example:
        <pre>
        Io> getopt("a:b", "-a1 -b arg" split)
        ==> list(list("-a", "1"), list("-b", nil))
        </pre>
    */
    getopt := method(
        args := call evalArgs
        GetOpt performWithArgList(
            "with", args exSlice(0, call argCount - 1)
        ) getopt(args last)
    )

    /*doc Object getoptGNU
        Shortcut method, returns a list of arguments parsed with GetOpt's getoptGNU().

        <pre>
        getoptGNU(shortlist, longlist, args) -> opts
        getoptGNU(shortlist, args) -> opts
        </pre>
    */
    getoptGNU := method(
        args := call evalArgs
        GetOpt performWithArgList(
            "with", args exSlice(0, call argCount - 1)
        ) getoptGNU(args last)
    )
)
