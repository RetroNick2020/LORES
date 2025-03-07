_TEXT   SEGMENT  WORD PUBLIC 'CODE'
_TEXT   ENDS
_DATA   SEGMENT  WORD PUBLIC 'DATA'
_DATA   ENDS
CONST   SEGMENT  WORD PUBLIC 'CONST'
CONST   ENDS
_BSS    SEGMENT  WORD PUBLIC 'BSS'
_BSS    ENDS
DGROUP  GROUP    CONST, _BSS, _DATA
        ASSUME  CS: _TEXT, DS: DGROUP, SS: DGROUP

EXTRN   _edgeH:         BYTE
EXTRN   _edgeV:         BYTE
EXTRN   _tileMap:       DWORD
EXTRN   _widthMap:      WORD
EXTRN   _spanMap:       WORD

_TEXT   SEGMENT

        ASSUME  DS: NOTHING

;
; Tile into memory buffer
;
tileBufRow      PROC NEAR
; s             = bp+4
; t             = bp+6
; widthBuf      = bp+8
; heightBuf     = bp+10
; buf           = bp+12, bp+14
; x             = bp-2
; y             = bp-4
; ss            = bp-6
; tilerow       = bp-10, bp-8
; tile          = bp-14, bp-12
; span          = bp-16
; width         = bp-18
; height        = bp-20
        mov     ax, WORD PTR [bp+4]     ; s
        shr     ax, 1
        mov     WORD PTR [bp-6], ax     ; ss = s/2
        shl     ax, 1
; x = 16 - s; // x is the width of the first tile and start of the second tile column
        sub     ax, 16
        neg     ax
        mov     WORD PTR [bp-2], ax     ; x
; if (x >= widthBuf)
        cmp     ax, WORD PTR [bp+8]     ; widthBuf
        jl      tilewiderow
;
; Only one tile wide
;
        mov     ax, WORD PTR [bp+8]     ; widthBuf
        shr     ax, 1
        mov     WORD PTR [bp-18], ax    ; width/2 = widthBuf/2
        jmp     tileMem
;
; Two or more tiles wide
;
tilewiderow:
; tileMem(s, t, x, height, *tile++, widthBuf >> 1, buf);
        shr     ax, 1
        mov     WORD PTR [bp-18], ax    ; width/2 = x/2
        call    tileMem
        add     WORD PTR [bp-10], 4     ; tilerow++
        mov     BYTE PTR [bp-6], 0      ; ss = 0
; buf += x >> 1;
        mov     ax, WORD PTR [bp-2]     ; x
        shr     ax, 1
        add     WORD PTR [bp+12], ax    ; OFFSET buf
        jmp     SHORT @F
tilemidrow:
; tileMem(0, t, 16, height, *tile++, widthBuf >> 1, buf);
        mov     WORD PTR [bp-18], 8     ; width/2 = 8
        call    tileMem
; tile++;
        add     WORD PTR [bp-10], 4     ; OFFSET tilerow
; buf += 8;
        add     WORD PTR [bp+12], 8     ; OFFSET buf
; x   += 16;
        add     WORD PTR [bp-2], 16     ; x
; while (x < (widthBuf - 16))
@@:     mov     ax, WORD PTR [bp+8]     ; widthBuf
        sub     ax, WORD PTR [bp-2]     ; x
        cmp     ax, 16
        jg      tilemidrow
; tileMem(0, t, widthBuf - x, height, *tile, widthBuf >> 1, buf);
        shr     ax, 1
        mov     WORD PTR [bp-18], ax    ; width/2 = (widthBuf - x)/2
;       jmp     tileMem                 ; Fall through
tileBufRow      ENDP

tileMem         PROC NEAR
; s             = bp+4
; t             = bp+6
; widthBuf      = bp+8
; heightBuf     = bp+10
; buf           = bp+12, bp+14
; x             = bp-2
; y             = bp-4
; ss            = bp-6
; tilerow       = bp-10, bp-8
; tile          = bp-14, bp-12
; span          = bp-16
; width         = bp-18
; height        = bp-20
; es:di => buf
; ds:si => tile
; bx => width
; dx => height
        les     di, DWORD PTR [bp+12]   ; buf
; tile   += t * 8 + (s >> 1);
        lds     si, DWORD PTR [bp-10]   ; tilerow
        lds     si, DWORD PTR [si]      ; tile
        add     si, WORD PTR [bp+6]     ; t * 8
        add     si, WORD PTR [bp-6]     ; ss = s >> 1
        mov     dx, WORD PTR [bp-20]    ; height
        mov     bx, WORD PTR [bp-18]    ; width/2
        push    bp
        mov     bp, WORD PTR [bp+8]     ; widthBuf
        shr     bp, 1
        sub     bp, bx                  ; span
        mov     cx, bx
        shr     cx, 1
        jc      @F
tile_e:
    rep movsw
        add     di, bp                  ; span
        add     si, 8                   ; tile
        sub     si, bx
        mov     cx, bx
        shr     cx, 1
        dec     dx                      ; height
        jnz     tile_e
        pop     bp
        ret
tile_o:
        mov     cx, bx
        shr     cx, 1
@@: rep movsw
        movsb
        add     di, bp                  ; span
        add     si, 8                   ; tile
        sub     si, bx
        dec     dx                      ; height
        jnz     tile_o
        pop     bp
        ret
tileMem         ENDP

        ASSUME  DS: DGROUP

        PUBLIC  _tileBuf
;void tileBuf(unsigned int s, unsigned int t, int widthBuf, int heightBuf, unsigned char far *buf)
_tileBuf    PROC NEAR
        push    bp
        mov     bp, sp
        sub     sp, 24
        push    di
        push    si
; s             = bp+4
; t             = bp+6
; widthBuf      = bp+8
; heightBuf     = bp+10
; buf           = bp+12, bp+14
; x             = bp-2
; y             = bp-4
; ss            = bp-6
; tilerow       = bp-10, bp-8
; tile          = bp-14, bp-12
; span          = bp-16
; width         = bp-18
; height        = bp-20
;
; unsigned char far * far *tilerow;
; spanMap   = widthMap << 2 = widthMap * 4
; tilerow = tileMap + ((t >> 4) * widthMap * 4 + (s >> 4) * 4);
; tileRow = tileMap + ((t/16) * widthMap*4 + s/4)
;         = tileMap + (t/4 * widthMap + s/4
        mov     ax, WORD PTR [bp+6]     ; t
        and     al, 0F0h
        shr     ax, 1
        shr     ax, 1
        mul     WORD PTR DGROUP:_widthMap
        mov     dx, WORD PTR [bp+4]     ; s
        and     dl, 0F0h
        shr     dx, 1
        shr     dx, 1
        add     ax, dx
        add     ax, WORD PTR DGROUP:_tileMap
        mov     dx, WORD PTR DGROUP:_tileMap+2
        mov     WORD PTR [bp-10], ax    ; OFFSET tilerow
        mov     WORD PTR [bp-8], dx     ; SEG tilerow
; s &= 0x0F;
        and     WORD PTR [bp+4], 0Fh    ; s
; t &= 0x0F;
        mov     bx, WORD PTR [bp+6]     ; t
        and     bx, 000Fh
; y  = 16 - t; // y is the height of the first tile and start of second tile row
        mov     ax, 16
        sub     ax, bx                  ; t
        shl     bx, 1
        shl     bx, 1
        shl     bx, 1
        mov     WORD PTR [bp+6], bx     ; t
        mov     WORD PTR [bp-4], ax     ; y
; if (y >= heightBuf)
        cmp     ax, WORD PTR [bp+10]    ;  heightBuf
        jl      tiletallrows
;
; Only one tile tall
;
; tileBufRow(s, t, heightBuf, tilerow, widthBuf, buf);
        mov     ax, WORD PTR [bp+10]    ; height = heightBuf
        jmp     SHORT tilebuflast
;
; Two or more tiles tall
;
tiletallrows:
; tileBufRow(s, t, y, tilerow, widthBuf, buf);
        mov     WORD PTR [bp-20], ax    ; height = y
        push    WORD PTR [bp+12]        ; OFFSET buf
        push    WORD PTR [bp-10]        ; OFFSET tilerow
        push    ds
        call    tileBufRow
        pop     ds
; tilerow += spanMap;
        pop     ax
        add     ax, DGROUP:_spanMap
        mov     WORD PTR [bp-10], ax    ; OFFSET tilerow
; buf     += (widthBuf * y) >> 1;
        mov     ax, WORD PTR [bp+8]     ; widthBuf
        mul     WORD PTR [bp-20]        ; height
        shr     ax, 1
        pop     bx                      ; OFFSET buf
        add     ax, bx
        mov     WORD PTR [bp+12], ax    ; OFFSET buf
        mov     BYTE PTR [bp+6], 0      ; t = 0
        jmp     SHORT @F
tilemidrows:
; tileBufRow(s, 0, 16, tilerow, widthBuf, buf);
        mov     WORD PTR [bp-20], 16    ; height = 16
        push    WORD PTR [bp+12]        ; OFFSET buf
        push    WORD PTR [bp-10]        ; OFFSET tilerow
        push    ds
        call    tileBufRow
        pop     ds
; tilerow += spanMap;
        pop     ax
        add     ax, DGROUP:_spanMap
        mov     WORD PTR [bp-10], ax    ; OFFSET tilerow
; buf += widthBuf * 8;
        mov     ax, WORD PTR [bp+8]     ; widthBuf
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        pop     bx                      ; OFFSET buf
        add     ax, bx
        mov     WORD PTR [bp+12], ax    ; OFFSET buf
; y += 16;
        add     WORD PTR [bp-4], 16     ; y
; while (y < (heightBuf - 16)) => ((heightBuf - y) > 16)
@@:     mov     ax, WORD PTR [bp+10]    ; heightBuf
        sub     ax, WORD PTR [bp-4]     ; y
        cmp     ax, 16
        jg      tilemidrows
; tileBufRow(s, 0, heightBuf - y, tilerow, widthBuf, buf);
tilebuflast:
        mov     WORD PTR [bp-20], ax    ; height = heightBuf - y
        push    ds
        call    tileBufRow
        pop     ds
        pop     si
        pop     di
        mov     sp, bp
        pop     bp
        ret
_tileBuf        ENDP

        PUBLIC  _tileEdgeH
_tileEdgeH      PROC NEAR
        push    bp
        mov     bp, sp
        push    di
        push    si
; s             = bp+4
; t             = bp+6
; tile          = bp+8
; es:di => &edgeH[x]
; dx:bx => tile
; ds:si => *tile
        push    ds
        mov     ax, ds
        mov     es, ax
        ASSUME  DS: NOTHING, ES: DGROUP
        mov     di, OFFSET DGROUP:_edgeH
        mov     bx, WORD PTR [bp+8]     ; OFFSET tile
        mov     dx, WORD PTR [bp+10]    ; SEG tile
; tileMemH(0, s, t, 16 - s, *tile++);
        mov     ds, dx
        lds     si, [bx]                ; *tile
        mov     cx, 8
        mov     ax, WORD PTR [bp+4]     ; s
        shr     ax, 1                   ; s >> 1
        sub     cx, ax                  ; (16 - s) >> 1
        add     si, ax                  ; s
; tile += (t << 3) + (s >> 1);
        mov     ax, WORD PTR [bp+6]
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        mov     WORD PTR [bp+6], ax     ; t => t << 3
        add     si, ax
        shr     cx, 1
    rep movsw
        adc     cx, cx
    rep movsb
        add     bx, 4                   ; tile++
; for (x = 16 - s; x < 160 - 16; x += 16)
tileedgeh:
; tileMemH(x, 0, t, 16, *tile++);
        mov     ds, dx
        lds     si, [bx]                ; *tile
        add     si, WORD PTR [bp+6]     ; t << 3
        mov     cx, 8/2
    rep movsw
        add     bx, 4                   ; tile++;
        cmp     di, OFFSET DGROUP:_edgeH + (160 - 16) / 2
        jb      tileedgeh
; tileMemH(x, 0, t, 160 - x, *tile++);
        mov     ds, dx
        lds     si, [bx]                ; *tile
        mov     cx, OFFSET DGROUP:_edgeH + 160 / 2
        sub     cx, di                  ; (160 - x) >> 1
        add     si, WORD PTR [bp+6]     ; t
        shr     cx, 1
    rep movsw
        adc     cx, cx
    rep movsb
        pop     ds
        ASSUME  DS: DGROUP, ES: NOTHING
        pop     si
        pop     di
        mov     sp, bp
        pop     bp
        ret
_tileEdgeH      ENDP

        PUBLIC  _tileEdgeH2
_tileEdgeH2     PROC NEAR
        push    bp
        mov     bp, sp
        push    di
        push    si
; s             = bp+4
; t             = bp+6
; tile          = bp+8
; es:di => &edgeH[x]
; dx:bx => tile
; ds:si => *tile
        push    ds
        mov     ax, ds
        mov     es, ax
        ASSUME  DS: NOTHING, ES: DGROUP
        mov     di, OFFSET DGROUP:_edgeH
        lds     bx, DWORD PTR [bp+8]    ; OFFSET tile
; tileMemH2(0, s, t, 16 - s, *tile++);
        lds     si, [bx]                ; *tile
        mov     cx, 8
        mov     ax, WORD PTR [bp+4]     ; s
        shr     ax, 1                   ; s >> 1
        sub     cx, ax                  ; (16 - s) >> 1
        add     si, ax                  ; s
; tile += (t << 3) + (s >> 1);
        mov     ax, WORD PTR [bp+6]
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        mov     WORD PTR [bp+6], ax     ; t => t << 3
        add     si, ax
;
; Even row
;
        mov     dx, cx
        shr     cx, 1
    rep movsw
        adc     cx, cx
    rep movsb
        mov     cx, dx
;
; Odd row
;
        mov     ax, WORD PTR [bp+4]     ; s
        shr     ax, 1                   ; s >> 1
        add     si, ax                  ; s
        sub     di, cx
        add     di, 80
        shr     cx, 1
    rep movsw
        adc     cx, cx
    rep movsb
        sub     di, 80
        add     bx, 4                   ; tile++
        mov     dx, WORD PTR [bp+10]    ; SEG tile
; for (x = 16 - s; x < 160 - 16; x += 16)
tileedgeh2:
; tileMemH2(x, 0, t, 16, *tile++);
        mov     ds, dx
        lds     si, [bx]                ; *tile
        add     si, WORD PTR [bp+6]     ; t << 3
;
; Even row
;
        mov     cx, 8/2
    rep movsw
;
; Odd row
;
        add     di, 80 - 16/2
        mov     cx, 8/2
    rep movsw
        sub     di, 80
        add     bx, 4                   ; tile++;
        cmp     di, OFFSET DGROUP:_edgeH + (160 - 16) / 2
        jb      tileedgeh2
; tileMemH2(x, 0, t, 160 - x, *tile++);
        mov     ds, dx
        lds     si, [bx]                ; *tile
        mov     cx, OFFSET DGROUP:_edgeH + 160 / 2
        sub     cx, di                  ; (160 * 2 - x) >> 1
        add     si, WORD PTR [bp+6]     ; t
;
; Even row
;
        mov     dx, cx                  ; done with dx
        shr     cx, 1
    rep movsw
        adc     cx, cx
    rep movsb
        mov     cx, dx
;
; Odd row
;
        sub     di, cx
        add     di, 80
        sub     si, cx
        add     si, 8
        shr     cx, 1
    rep movsw
        adc     cx, cx
    rep movsb
        pop     ds
        ASSUME  DS: DGROUP, ES: NOTHING
        pop     si
        pop     di
        mov     sp, bp
        pop     bp
        ret
_tileEdgeH2      ENDP

        PUBLIC  _tileEdgeV

; void tileEdgeV(unsigned int s, unsigned int t, unsigned char far * far *tile)
_tileEdgeV      PROC NEAR
        push    bp
        mov     bp, sp
        push    di
        push    si
; s             = bp+4
; t             = bp+6
; tile          = bp+8
; es:di => &edgeV[y]
; dx:bx => tile
; ds:si => *tile
        push    ds
        mov     ax, ds
        mov     es, ax
        ASSUME  DS: NOTHING, ES: DGROUP
        mov     di, OFFSET DGROUP:_edgeV
        mov     bx, WORD PTR [bp+8]     ; OFFSET tile
        mov     dx, WORD PTR [bp+10]    ; SEG tile
; tileMemV(0, s, t, 16 - t, *tileptr);
        mov     ds, dx
        lds     si, [bx]                ; *tile
        mov     cx, 16
        mov     ax, WORD PTR [bp+6]     ; t
        sub     cx, ax                  ; 16 - t
; tile += (t << 3) + (s >> 1);
        shr     WORD PTR [bp+4], 1      ; s => s >> 1
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        add     si, WORD PTR [bp+4]     ; s
        add     si, ax
@@:     movsb
        add     si, 7
        loop    @B
; tile += spanMap;
        add     bx, es:_spanMap         ; tile
; for (y = 16 - t; y < 100 - 16; y += 16)
tileedgev:
; tileMemV(y, s, 0, 16, *tileptr);
        mov     ds, dx
        lds     si, [bx]                ; *tile
        add     si, WORD PTR [bp+4]     ; s
        REPT    16
        movsb
        add     si, 7
        ENDM
; tile += spanMap;
        add     bx, es:_spanMap         ; tile
        cmp     di, OFFSET DGROUP:_edgeV + 100 - 16
        jb      tileedgev
; tileMemV(y, s, 0, 100 - y, *tileptr);
        mov     ds, dx
        lds     si, [bx]                ; *tile
        mov     cx, OFFSET DGROUP:_edgeV + 100
        sub     cx, di                  ; 100 - y
        add     si, WORD PTR [bp+4]     ; s
@@:     movsb
        add     si, 7
        loop    @B
        pop     ds
        ASSUME  DS: DGROUP, ES: NOTHING
        pop     si
        pop     di
        mov     sp, bp
        pop     bp
        ret
_tileEdgeV    ENDP

PUBLIC    _spriteBuf

;void spriteBuf(int x, int y, int width, int height, unsigned char far *spriteImg, int span, unsigned char far *buf)
_spriteBuf      PROC NEAR
        push    bp
        mov     bp, sp
        push    di
        push    si
        push    ds
        ASSUME  DS: NOTHING
; x             = bp+4
; y             = bp+6
; width         = bp+8
; height        = bp+10
; sprite        = bp+12, bp+14
; span          = bp+16
; buf           = bp+18, bp+20
        mov     ax, WORD PTR [bp+6]     ; y
        mov     cx, WORD PTR [bp+4]     ; x
        shr     cx, 1
        imul    WORD PTR [bp+16]        ; span
        add     ax, cx
        add     WORD PTR [bp+18], ax    ; OFFSET buf
        shr     WORD PTR [bp+8], 1      ; width
        mov     cx, WORD PTR [bp+8]     ; width
        sub     WORD PTR [bp+16], cx    ; span
        mov     dx, WORD PTR [bp+10]    ; height
        lds     si, DWORD PTR [bp+12]   ; sprite
        les     di, DWORD PTR [bp+18]   ; buf
        test    BYTE PTR [bp+4], 1      ; x
        jnz     dstodd
evenx:
        lodsb
        cmp     al, 088h                ; Both nybbles transparent?
        je      evennxt
        mov     bl, al
        mov     bh, al
        and     bx, 0F00Fh
        cmp     bl, 08h                 ; Low nybble transparent?
        je      exparlo
        cmp     bh, 080h                ; High nybble transparent?
        je      exparhi
        stosb
        loop    evenx
        jmp     SHORT @F
exparlo:
        mov     al, es:[di]
        and     al, 0Fh
        or      al, bh
        stosb
        loop    evenx
        jmp     SHORT @F
exparhi:
        mov     al, es:[di]
        and     al, 0F0h
        or      al, bl
        stosb
        loop    evenx
        jmp     SHORT @F
evennxt:
        inc     di
        loop    evenx
@@:     mov     cx, WORD PTR [bp+8]     ; width
        add     di, WORD PTR [bp+16]    ; span
        dec     dx                      ; height
        jnz     evenx
        jmp    sprtexit
dstodd:
        dec     WORD PTR [bp+16]        ; span
oddfirst:
        xor     ax, ax
        lodsb
        ror     ax, 1
        ror     ax, 1
        ror     ax, 1
        ror     ax, 1
        cmp     ah, 80h;                ; High nybble transparent?
        je      @F
        mov     bh, es:[di]
        and     bh, 0Fh
        or      ah, bh
        mov     es:[di], ah
@@:     inc     di
        mov     bh, al
        loop    oddx
        jmp     SHORT oddlast
oddx:
        xor     ax, ax
        lodsb
        ror     ax, 1
        ror     ax, 1
        ror     ax, 1
        ror     ax, 1
        mov     bl, bh
        or      bl, ah
        cmp     bl, 088h                ; Both nybbles transparent?
        je      oddnxt
        cmp     bh, 08h                 ; Low nybble transparent?
        je      oxparlo
        cmp     ah, 080h                ; High nybble transparent?
        je      oxparhi
        mov     bh, al
        mov     al, bl
        stosb
        loop    oddx
        jmp     SHORT oddlast
oxparlo:
        mov     bh, al
        mov     al, es:[di]
        and     al, 0Fh
        or      al, ah
        stosb
        loop    oddx
        jmp     SHORT oddlast
oxparhi:
        xchg    bh, al
        mov     bl, es:[di]
        and     bl, 0F0h
        or      al, bl
        stosb
        loop    oddx
        jmp     SHORT oddlast
oddnxt:
        mov     bh, al
        inc     di
        loop    oddx
oddlast:
        cmp     bh, 08h;                ; Low nybble transparent?
        je      @F
        mov     ah, es:[di]
        and     ah, 0F0h
        or      ah, bh
        mov     es:[di], ah
@@:     inc     di
        mov     cx, WORD PTR [bp+8]     ; width
        add     di, WORD PTR [bp+16]    ; span
        dec     dx                      ; height
        jz      sprtexit
        jmp     oddfirst
sprtexit:
        pop     ds
        ASSUME  DS: DGROUP
        pop     si
        pop     di
        mov     sp, bp
        pop     bp
        ret
_spriteBuf      ENDP

        PUBLIC  _cpyBuf2Buf
_cpyBuf2Buf     PROC NEAR
        push    bp
        mov     bp, sp
        push    di
        push    si
        push    ds
; width     = bp+4
; height    = bp+6
; spanSrc   = bp+8
; bufSrc    = bp+10
; spanDst   = bp+14
; bufDst    = bp16
        mov     dh, BYTE PTR [bp+6]     ; height
        mov     cx, WORD PTR [bp+4]     ; width
        shr     cx, 1
        mov     dl, cl
        les     di, DWORD PTR [bp+16]   ; bufDst
        lds     si, DWORD PTR [bp+10]   ; bufSrc
        ASSUME  DS: NOTHING
        mov     bx, WORD PTR [bp+8]     ; spanSrc
        push    bp
        mov     bp, WORD PTR [bp+14]    ; spanDst
@@:     shr     cx, 1
    rep movsw
        adc     cx, cx
    rep movsb
        mov     cl, dl
        sub     si, cx
        add     si, bx    ; bufSrc
        sub     di, cx
        add     di, bp    ; bufDst
        dec     dh
        jne     @B
        pop     bp
        pop     ds
        ASSUME  DS: DGROUP
        pop     si
        pop     di
        mov     sp, bp
        pop     bp
        ret

_cpyBuf2Buf     ENDP


_TEXT   ENDS
END
