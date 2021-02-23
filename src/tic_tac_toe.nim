import tables
import sdl2
import sdl2/ttf
import sugar
import random

ttfInit()
randomize()

const font_data = slurp("../LiberationMono-Regular.ttf").cstring
let font_RWops = font_data.rwFromConstMem(font_data.len)
let font = font_RWops.openFontRW(0, 120)

let width = 100.cint
let margin = (width.float * 0.03).cint
let screen_width = (width * 3).float.cint + margin

var window = createWindow("Window Name", 100, 100, screen_width, screen_width, SDL_WINDOW_SHOWN)
var renderer = createRenderer(window, -1, Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture)

var event = sdl2.defaultEvent
var rungame = true

proc button(renderer: RendererPtr, label: string, x, y, width, height: cint,
                        normal_color, hover_color, font_color: Color, callback: proc) =
    var rect = (x, y, width, height)

    var cur_x, cur_y: cint
    let mouse_state = getMouseState(cur_x, cur_y)

    if x < cur_x and y < cur_y and x + width > cur_x and y + height > cur_y:
        renderer.setDrawColor(hover_color)
        if (1.uint and mouse_state) > 0:
            callback()

    else:
        renderer.setDrawColor(normal_color)

    renderer.fillRect(rect)

    let surface = renderTextBlended(font, label, font_color)
    let texture = createTextureFromSurface(renderer, surface)

    var font_width, font_height: cint
    texture.queryTexture(nil, nil, addr font_width, nil)
    var font_rect = (x + ((width-font_width) div 2), y, font_width, height)

    renderer.copy(texture, nil, addr font_rect)

var board: array[0..2, array[0..2, char]] = [
    [' ',' ',' '],
    [' ',' ',' '],
    [' ',' ',' ']
]

type 
    BoardStateEnum = enum
        bseCloseWin,
        bseVictory,
        bseInsignificant,
    
    DirectionEnum = enum
     deDiagonal,
     deVertical,
     deHorizontal,

    Direction = object
        case direction: DirectionEnum
            of deDiagonal: inverse: bool
            of deVertical, deHorizontal: line: range[0..2]

    BoardState = object
        case state: BoardStateEnum
            of bseCloseWin: last: tuple[i, j: int]
            of bseVictory: 
                path: array[0..2, tuple[i, j: int]]
                side: char
            else: discard

proc getBoardState(): BoardState = 
    result = BoardState(state: bseInsignificant)

    let paths = [
        # Diagonal paths
        [(0, 0), (1, 1), (2, 2)],
        [(0, 2), (1, 1), (2, 0)],
        # Horizontal paths
        [(0, 0), (0, 1), (0, 2)],
        [(1, 0), (1, 1), (1, 2)],
        [(2, 0), (2, 1), (2, 2)],
        # Vertical paths
        [(0, 0), (1, 0), (2, 0)],
        [(0, 1), (1, 1), (2, 1)],
        [(0, 2), (1, 2), (2, 2)]
    ]

    for p in paths:
        let states = (block: collect newSeq: (for (i, j) in p: board[i][j]))
        var table = toCountTable(states)
        table.del(' ')
        for k, v in table:
            if v == 3: 
                return BoardState(state: bseVictory, path: p, side: k)
            if v == 2: 
                # Go find the empty block
                for (i, j) in p:
                    if board[i][j] == ' ':
                        result = BoardState(state: bseCloseWin, last: (i, j))
    
proc on_button_press(i, j: int) =
    if board[i][j] != ' ' or not rungame:
        return

    board[i][j] = 'X'
    
    # Call getBoardState
    # If BoardState == win: break
    # If BoardState == closewin: place our token on closewin spot
    # If BoardState == insignificat: place token on random spot
    block placement_handler:
        let boardState = getBoardState()
        case boardState.state:
            of bseVictory:
                break placement_handler
            of bseCloseWin:
                let (i, j) = boardState.last
                board[i][j] = 'O'
            of bseInsignificant:
                var spots = newSeq[tuple[i, j: int]]()
                
                for i, a in pairs(board):
                    for j, c in pairs(a):
                        if c == ' ':
                            spots.add((i, j))

                if spots.len == 0:
                    # Draw
                    rungame = false
                    return
    
                let choice = sample(spots)
                board[choice.i][choice.j] = 'O'
    
    # Victory handler
    let boardState = getBoardState()
    if boardState.state == bseVictory:
        rungame = false

proc board_button(label: string, border, x, y, width: cint, i, j: int) =
    renderer.button(label,
        border+x, border+y, width-border, width-border,
        (190.uint8, 190.uint8, 190.uint8, 255.uint8),
        (225.uint8, 225.uint8, 225.uint8, 255.uint8),
        (0.uint8, 0.uint8, 0.uint8, 0.uint8),
        () => on_button_press(i, j)
    )

while true:
    while pollEvent(event):
        if event.kind == QuitEvent:
            destroy renderer
            destroy window
            quit(0)

    renderer.setDrawColor(0,0,0,255)
    renderer.clear()

    for i, a in pairs(board):
        for j, c in pairs(a):
            board_button($c, margin, j*width, i*width, width, i, j)

    if rungame == false:
        renderer.setDrawBlendMode(BlendModeMod)
        let state = getBoardState()
        if state.state == bseVictory:
            if state.side == 'X':
                renderer.setDrawColor((0.uint8, 255.uint8, 0.uint8, 0.uint8))
            else:
                renderer.setDrawColor((255.uint8, 0.uint8, 0.uint8, 0.uint8))
            let victory_path = state.path
            for (i, j) in victory_path:
                var rect = ((j*width).cint+margin, (i*width).cint+margin, width-margin, width-margin)
                renderer.fillRect(rect)

        elif state.state == bseInsignificant:
            renderer.setDrawColor((255.uint8, 255.uint8, 0.uint8, 0.uint8))
            for i in 0..2:
                for j in 0..2:
                    var rect = ((j*width).cint+margin, (i*width).cint+margin, 
                                 width-margin, width-margin)
                    renderer.fillRect(rect)
        renderer.setDrawBlendMode(BlendModeNone)

    renderer.present()

destroy renderer
destroy window
