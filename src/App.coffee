class App

  # @link http://hackage.haskell.org/package/pandoc For options description
  @outputTypesAdd = [
    'gfm' # use GitHub markdown variant
  ]

  @outputTypesRemove = [
  ]

  @extraOptions = [
    '--atx-headers' # Setext-style headers (underlined) | ATX-style headers (prefixed with hashes)
  ]

  ###*
  # @param {sync-exec} _exec Required lib
  # @param {path} _path Required lib
  # @param {fs} _fs Required lib
  # @param {Utils} utils My lib
  # @param {Formatter} formatter My lib
  # @param {PageFactory} pageFactory My lib
  # @param {Logger} logger My lib
  ###
  constructor: (@_exec, @_path, @_fs, @utils, @formatter, @pageFactory, @logger) ->
    typesAdd = App.outputTypesAdd.join '+'
    typesRemove = App.outputTypesRemove.join '-'
    typesRemove = if typesRemove then '-' + typesRemove else ''
    types = typesAdd + typesRemove
    @pandocOptions = [
      if types then '-t ' + types else ''
      App.extraOptions.join ' '
    ].join ' '


  ###*
  # Converts HTML files to MD files.
  # @param {string} dirIn Directory to go through
  # @param {string} dirOut Directory where to place converted MD files
  ###
  convert: (dirIn, dirOut) ->
    filePaths = @utils.readDirRecursive dirIn
    pages = (@pageFactory.create filePath for filePath in filePaths when filePath.endsWith '.html')

    indexHtmlFiles = []
    for page in pages
      do (page) =>
        if page.fileName == 'index.html'
          indexHtmlFiles.push @_path.join page.space, 'index' # gitit requires link to pages without .md extension
        @convertPage page, dirIn, dirOut, pages

    @writeGlobalIndexFile indexHtmlFiles, dirOut if not @utils.isFile dirIn
    @logger.info 'Conversion done'


  ###*
  # Converts HTML file at given path to MD.
  # @param {Page} page Page entity of HTML file
  # @param {string} dirOut Directory where to place converted MD files
  ###
  convertPage: (page, dirIn, dirOut, pages) ->
    @logger.info 'Parsing ... ' + page.path
    text = page.getTextToConvert pages
    fullOutFileName = @_path.join dirOut, page.space, page.fileNameNew

    @logger.info 'Making Markdown ... ' + fullOutFileName
    @writeMarkdownFile text, fullOutFileName
    @utils.copyAssets @utils.getDirname(page.path), @utils.getDirname(fullOutFileName)
    @logger.info 'Done\n'


  ###*
  # @param {string} text Makdown content of file
  # @param {string} fullOutFileName Absolute path to resulting file
  # @return {string} Absolute path to created MD file
  ###
  writeMarkdownFile: (text, fullOutFileName) ->
    fullOutDirName = @utils.getDirname fullOutFileName
    @_fs.mkdirSync fullOutDirName, recursive: true

    command = 'pandoc -f html #{@pandocOptions} -o "#{fullOutFileName}"'
    out = @_exec command, cwd: fullOutDirName, input: text
    @logger.error out.stderr if out.status > 0


  ###*
  # @param {array} indexHtmlFiles Relative paths of index.html files from all parsed Confluence spaces
  # @param {string} dirOut Absolute path to a directory where to place converted MD files
  ###
  writeGlobalIndexFile: (indexHtmlFiles, dirOut) ->
    globalIndex = @_path.join dirOut, 'index.md'
    $content = @formatter.createListFromArray indexHtmlFiles
    text = @formatter.getHtml $content
    @writeMarkdownFile text, globalIndex


module.exports = App
