#include <stdio.h>
#include <stdlib.h>
#include <dos.h>
#include <conio.h>
#include "lores.h"
#include "tiler.h"
#include "mapio.h"
#define ESCAPE          0x001B
#define LEFT_ARROW      0x4B00
#define RIGHT_ARROW     0x4D00
#define UP_ARROW        0x4800
#define DOWN_ARROW      0x5000
#define WALL_TOP        0x01
#define WALL_BOTTOM     0x02
#define WALL_LEFT       0x04
#define WALL_RIGHT      0x08
#define MAX_HEIGHT      (100/3)
#define MAX_WIDTH       (160/3)
#define FALSE           0
#define TRUE            (!FALSE)
#define DIR_ANY         0x00
#define DIR_UP          0x01
#define DIR_DOWN        0x02
#define DIR_LEFT        0x04
#define DIR_RIGHT       0x08
#define CELL_SOLVED     0x80
#define CELL_TRACED     0x40
unsigned int mapWidth, mapHeight;
unsigned char maze[MAX_HEIGHT][MAX_WIDTH];
unsigned char Enter, Exit, xDeadEnd, yDeadEnd;
/*
 * Map and tile data
 */
unsigned char far *tilesetExit;
unsigned char far *tileExitAnimate[4];
// WALL_TOP        0x01
// WALL_BOTTOM     0x02
// WALL_LEFT       0x04
// WALL_RIGHT      0x08
unsigned char far *tilesetWalls;
unsigned char far *maze2map[16];
unsigned char far *tilemap[MAX_HEIGHT * MAX_WIDTH];
/*
 * 10X10 Sprite
 */
#define FACE_WIDTH      faceWidth
#define FACE_HEIGHT     faceHeight
int faceWidth, faceHeight;
unsigned char far *face;
/*
 * Maze generator
 */
int solve(int x, int y, unsigned char dirEntry)
{
    unsigned char dirOptions;
    /*
     * Keep looking for a solution until exit or dead-end is found
     */
    while (!(maze[y][x] & CELL_SOLVED))
    {
        /*
         * Check if this cell already traced (avoid infinite recursion)
         */
        if (maze[y][x] & CELL_TRACED)
            return FALSE;
        maze[y][x] |= CELL_TRACED;
        /*
         * Get move direction options - not walls or entry direction
         */
        dirOptions = ~(maze[y][x] | dirEntry) & 0x0F;
        /*
         * Check for dead-end
         */
        if (!dirOptions)
        {
            xDeadEnd = x;
            yDeadEnd = y;
            return FALSE;
        }
        /*
         * Look for a single direction to move
         */
        if (dirOptions == DIR_UP)
        {
            y--;
            dirEntry = DIR_DOWN;
        }
        else if (dirOptions == DIR_DOWN)
        {
            y++;
            dirEntry = DIR_UP;
        }
        else if (dirOptions == DIR_LEFT)
        {
            x--;
            dirEntry = DIR_RIGHT;
        }
        else if (dirOptions == DIR_RIGHT)
        {
            x++;
            dirEntry = DIR_LEFT;
        }
        else
        {
            /*
             * Intersection of multiple routes
             */
            unsigned char dir;

            for (dir = 0x08; dir; dir >>= 1)
            {
                if (dir & dirOptions)
                {
                    if (dir == DIR_UP)
                    {
                        if (solve(x, y - 1, DIR_DOWN))
                            return TRUE;
                    }
                    else if (dir == DIR_DOWN)
                    {
                        if (solve(x, y + 1, DIR_UP))
                            return TRUE;
                    }
                    else if (dir == DIR_LEFT)
                    {
                        if (solve(x - 1, y, DIR_RIGHT))
                            return TRUE;
                    }
                    else if (dir == DIR_RIGHT)
                    {
                        if (solve(x + 1, y, DIR_LEFT))
                            return TRUE;
                    }
                }
            }
            return FALSE;
        }
    }
    return TRUE;
}
void cleartrace(void)
{
    int i, j;

    for (i = 0; i < mapWidth; i++)
        for (j = 0; j < mapHeight; j++)
            maze[j][i] &= ~CELL_TRACED;
}
int buildmaze(void)
{
    int i, j;
    unsigned char wall, solved, solveCount;

    for (j = 0; j <= mapHeight; j++)
        hlin(0, mapWidth*3, j*3, WHITE);
    for (i = 0; i <= mapWidth; i++)
        vlin(i*3, 0, mapHeight*3, WHITE);
    for (i = 0; i < mapWidth; i++)
        for (j = 0; j < mapHeight; j++)
            maze[j][i] = WALL_TOP | WALL_BOTTOM | WALL_LEFT | WALL_RIGHT;
    /*
     * Pick entrance at left border and exit at right border
     */
    Enter = (rand() % (mapHeight - 2)) + 1;
    Exit  = (rand() % (mapHeight - 2)) + 1;
    /*
     * Set exit as solved
     */
    maze[Exit][mapWidth-1] |= CELL_SOLVED;
    /*
     * Add edges and entry/exit to view
     */
    vlin(0*3,  Enter * 3 + 1, Enter * 3 + 2, BLACK);
    vlin(mapWidth*3, Exit  * 3 + 1, Exit  * 3 + 2, BLACK);
    /*
     * Make initial pass erasing boxed-in cells
     */
    for (i = 0; i < mapWidth; i++)
    {
        for (j = 0; j < mapHeight; j++)
        {
            while (maze[j][i] == (WALL_TOP | WALL_BOTTOM | WALL_LEFT | WALL_RIGHT))
            {
                /*
                 * Open up a random wall
                 */
                wall = 1 << (rand() & 3);
                if ((i == 0     && wall == WALL_LEFT)
                 || (i == mapWidth-1  && wall == WALL_RIGHT)
                 || (j == 0      && wall == WALL_TOP)
                 || (j == mapHeight-1 && wall == WALL_BOTTOM))
                    /*
                     * Check border walls
                     */
                    continue;
                /*
                 * Erase wall
                 */
                if (wall == WALL_TOP)
                {
                    maze[j - 1][i] ^= WALL_BOTTOM;
                    hlin(i * 3 + 1, i * 3 + 2, j * 3, BLACK);
                }
                else if (wall == WALL_BOTTOM)
                {
                    maze[j + 1][i] ^= WALL_TOP;
                    hlin(i * 3 + 1, i * 3 + 2, (j + 1) * 3, BLACK);
                }
                else if (wall == WALL_LEFT)
                {
                    maze[j][i - 1] ^= WALL_RIGHT;
                    vlin(i * 3, j * 3 + 1, j * 3 + 2, BLACK);
                }
                else if (wall == WALL_RIGHT)
                {
                    maze[j][i + 1] ^= WALL_LEFT;
                    vlin((i + 1) * 3, j * 3 + 1, j * 3 + 2, BLACK);
                }
                maze[j][i] ^= wall;
            }
        }
    }
    /*
     * Check every cell for a solution
     */
    solveCount = 0;
    do
    {
        /*
         * Check for a stuck solver
         */
        if (solveCount++ > 1)
            return FALSE;
        solved = TRUE;
#ifdef EASY
        for (i = mapWidth-1; i >= 0; i--)
#else
        for (i = 0; i < mapWidth; i++)
#endif
        {
            for (j = 0; j < mapHeight; j++)
            {
                cleartrace();
                if (solve(i, j, DIR_ANY))
                    maze[j][i] |= CELL_SOLVED;
                else
                {
                    /*
                     * Erase a wall at last dead-end
                     */
                    solved = FALSE;
                    for (wall = 0x08; wall; wall >>= 1)
                    {
                        if ((xDeadEnd == 0           && wall == WALL_LEFT)
                         || (xDeadEnd == mapWidth-1  && wall == WALL_RIGHT)
                         || (yDeadEnd == 0           && wall == WALL_TOP)
                         || (yDeadEnd == mapHeight-1 && wall == WALL_BOTTOM))
                            /*
                             * Check border walls
                             */
                            continue;
                        if (maze[yDeadEnd][xDeadEnd] & wall)
                        {
                            /*
                             * Erase wall
                             */
                            if (wall == WALL_TOP)
                            {
                                if (maze[yDeadEnd - 1][xDeadEnd] & CELL_TRACED)
                                    continue;
                                maze[yDeadEnd - 1][xDeadEnd] ^= WALL_BOTTOM;
                                hlin(xDeadEnd * 3 + 1, xDeadEnd * 3 + 2, yDeadEnd * 3, BLACK);
                            }
                            else if (wall == WALL_BOTTOM)
                            {
                                if (maze[yDeadEnd + 1][xDeadEnd] & CELL_TRACED)
                                    continue;
                                maze[yDeadEnd + 1][xDeadEnd] ^= WALL_TOP;
                                hlin(xDeadEnd * 3 + 1, xDeadEnd * 3 + 2, (yDeadEnd + 1) * 3, BLACK);
                            }
                            else if (wall == WALL_LEFT)
                            {
                                if (maze[yDeadEnd][xDeadEnd - 1] & CELL_TRACED)
                                    continue;
                                maze[yDeadEnd][xDeadEnd - 1] ^= WALL_RIGHT;
                                vlin(xDeadEnd * 3, yDeadEnd * 3 + 1, yDeadEnd * 3 + 2, BLACK);
                            }
                            else if (wall == WALL_RIGHT)
                            {
                                if (maze[yDeadEnd][xDeadEnd + 1] & CELL_TRACED)
                                    continue;
                                maze[yDeadEnd][xDeadEnd + 1] ^= WALL_LEFT;
                                vlin((xDeadEnd + 1) * 3, yDeadEnd * 3 + 1, yDeadEnd * 3 + 2, BLACK);
                            }
                            maze[yDeadEnd][xDeadEnd] ^= wall;
                            break;
                        }
                    }
                }
            }
        }
    } while (!solved);
    return TRUE;
}
/*
 * Convert maze into tile map
 */
void buildmap(void)
{
    int row, col;
    unsigned char far *tileptr;

    for (row = 0; row < mapHeight; row++)
        for (col = 0; col < mapWidth; col++)
            tilemap[row * mapWidth + col] = maze2map[maze[row][col] & 0x0F];
    tilemap[Exit * mapWidth + mapWidth-1] = tileExitAnimate[0];
}
/*
 * Extended keyboard input
 */
unsigned short extgetch(void)
{
    unsigned short extch;

    extch = getch();
    if (!extch)
        extch = getch() << 8;
    return extch;
}

/*
 * Demo tiling and scrolling screen
 */
int main(int argc, char **argv)
{
    unsigned int mazeX, mazeY;
    unsigned int faceS, viewS, moveToS, faceT, moveToT, viewT;
    int incS, incT, i;
    unsigned long st;
    unsigned int adapter, scrolldir, seed;
    unsigned char cycleExit, quit;
    struct dostime_t time;
    int hours, minutes, seconds, hseconds;
    char *level;
    unsigned char far *tilesetExit;

    /*
     * Load assets
     */
    tilesetLoad("exit.set",   &tilesetExit,  16*16/2);
    tilesetLoad("walls.set",  &tilesetWalls, 16*16/2);
    spriteLoad("player.spr", &face, &faceWidth, &faceHeight);
    for (i = 0; i < 4; i++)
        tileExitAnimate[i] = tilesetExit + i * 16 * 16 / 2;
    for (i = 0; i < 16; i++)
        maze2map[i] = tilesetWalls + i * 16 * 16 / 2;
    /*
     * Set maze difficulty
     */
    mapWidth  = MAX_WIDTH/2;
    mapHeight = MAX_HEIGHT/2;
    level = "Medium";
    _dos_gettime(&time);
    seed = (time.hsecond << 8) | time.second;
    /*
     * Check for easy option
     */
    while (argc > 1)
    {
        argc--;
        argv++;
        switch (*argv[0])
        {
            case 'e': // Easy option
            case 'E':
                mapWidth  = MAX_WIDTH/3;
                mapHeight = MAX_HEIGHT/3;
                level = "Easy";
                break;
            case 'h': // Hard option
            case 'H':
                mapWidth  = MAX_WIDTH;
                mapHeight = MAX_HEIGHT;
                level = "Hard";
                break;
            default: // Seed parameter?
                seed = atoi(*argv);
        }
    }
    srand(seed);
    adapter = gr160(BLACK, BLACK);
    _dos_gettime(&time);
    seconds = (time.second + 4) % 60;
    while (time.second != seconds)
    {
        text(40, 46, rand() & 0x0F, "Maze Runner");
        text(48, 54, rand() & 0x0F, "by Resman");
        if (kbhit())
        {
            getch();
            break;
        }
        _dos_gettime(&time);
    }
    rect(40, 46, 88, 16, BLACK);
    while (!buildmaze())
    {
        if (kbhit() && (getch() == 'q'))
        {
            txt80();
            exit(-1);
        }
    };
    buildmap();
    //getch();
    /*
     * Set initial coordinates
     */
    mazeX   = 0;
    mazeY   = Enter;
    faceS   = (mazeX << 4) + 3;
    faceT   = (mazeY << 4) + 3;
    moveToS = faceS;
    moveToT = faceT;
    incS    = 0;
    incT    = 0;
    viewS   = 0;
    viewT   = (mapHeight/4) << 4;
    /*
     * Render initial view
     */
    viewInit(adapter, viewS, viewT, mapWidth, mapHeight, (unsigned char far * far *)tilemap);
    spriteEnable(0, faceS, faceT, FACE_WIDTH, FACE_HEIGHT, face);
    viewRefresh(0);
    cycleExit = 0;
    quit      = FALSE;
    hours      =
    minutes    =
    seconds    =
    hseconds   =
    frameCount = 0;
    while (!quit)
    {
#ifdef PROFILE
        rasterBorder(GREY); // Show game logic as grey border
#endif
        if (frameCount >= 3600)
        {
            /*
             * Capture every minute and zero frame count
             */
            minutes++;
            frameCount -= 3600;
        }
        /*
         * Update a Exit tile on-the-fly
         */
        if (!(frameCount & 0x0F))
            tileUpdate(mapWidth-1, Exit, tileExitAnimate[cycleExit++ & 0x03]);
        /*
         * Check keyboard input
         */
        if (moveToS == faceS && moveToT == faceT)
        {
            if (kbhit())
            {
                switch (extgetch())
                {
                    case UP_ARROW:
                        /*
                         * Move up
                         */
                        if (!(maze[mazeY][mazeX] & WALL_TOP))
                        {
                            mazeY--;
                            moveToT -= 1 << 4;
                            incT     = -2;
                        }
                        break;
                    case DOWN_ARROW:
                        /*
                         * Move down
                         */
                        if (!(maze[mazeY][mazeX] & WALL_BOTTOM))
                        {
                            mazeY++;
                            moveToT += 1 << 4;
                            incT     = 2;
                        }
                        break;
                    case LEFT_ARROW:
                        /*
                         * Move left
                         */
                        if (!(maze[mazeY][mazeX] & WALL_LEFT))
                        {
                            mazeX--;
                            moveToS -= 1 << 4;
                            incS     = -2;
                        }
                        break;
                    case RIGHT_ARROW:
                        /*
                         * Move right
                         */
                        if (!(maze[mazeY][mazeX] & WALL_RIGHT))
                        {
                            mazeX++;
                            moveToS += 1 << 4;
                            incS     = 2;
                        }
                        break;
                    case 'q':
                    case 'Q':
                    case ESCAPE:
                        hours    =
                        minutes  =
                        seconds  =
                        hseconds = 0;
                        quit = TRUE;
                        break;
                }
            }
        }
        if (incS || incT)
        {
            st = spritePosition(0, faceS + incS, faceT + incT);
            faceS = st;
            faceT = st >> 16;
            /*
             * Have we made it to our destination?
             */
            if (moveToS == faceS && moveToT == faceT)
            {
                /*
                 * Stop moving and check for exit
                 */
                incS = incT = 0;
                if (mazeX == mapWidth-1 && mazeY == Exit)
                {
                    hseconds = ((frameCount % 60) * 100) / 60;
                    seconds  = frameCount / 60;
                    if (seconds > 59)
                    {
                        minutes++;
                        seconds -= 60;
                    }
                    while (minutes > 59)
                    {
                        hours++;
                        minutes -= 60;
                    }
                    quit = TRUE;
                    frameCount = 0;
                    while (frameCount < 180)
                    {
                        text(32, 46, rand() & 0x0F, "You made it!");
                        if (kbhit())
                        {
                            getch();
                            frameCount = 1000;
                        }
                    }
                }
            }
        }
        /*
         * Attempt to keep sprite centered by scrolling map
         */
        scrolldir = 0;
        if (faceS < viewS + (80 - FACE_WIDTH/2))
            scrolldir = SCROLL_RIGHT2;
        else if (faceS > viewS + (80 - FACE_WIDTH/2))
            scrolldir = SCROLL_LEFT2;
        if (faceT < viewT + (50 - FACE_HEIGHT/2))
            scrolldir |= SCROLL_DOWN2;
        else if (faceT > viewT + (50 - FACE_HEIGHT/2))
            scrolldir |= SCROLL_UP2;
#ifdef PROFILE
        rasterBorder(BLACK);
#endif
        st = viewRefresh(scrolldir);
        viewS  = st;
        viewT  = st >> 16;
    }
    viewExit();
    txt80();
    printf("Level: %s\n", level);
    printf("Seed: %u\n", seed);
    printf("Elapsed time: %02d:%02d:%02d.%02d\n", hours, minutes, seconds, hseconds);
    return 0;
}
