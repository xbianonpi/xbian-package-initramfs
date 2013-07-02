#include <stdlib.h>
#include <stdio.h>
#include <linux/input.h>
#include <stdint.h>

void usage ( int argc, char *argv[] )
{
    printf("Usage:\n\t%s key input\n\nvalid keys are:\n\tlshift\t- Left Shift key\n" , argv[0]);

    exit(EXIT_FAILURE);
}

int main ( int argc, char *argv[], char *env[] )
{
    if ( argc != 3 )    usage(argc, argv);

    int key, res;
    uint8_t *bits = NULL;
    ssize_t bits_size = 0;

    if ( strcmp(argv[1], "lshift") == 0 )       key = KEY_LEFTSHIFT;
    else if ( strcmp(argv[1], "rshift") == 0 )  key = KEY_RIGHTSHIFT;
    else if ( strcmp(argv[1], "lalt") == 0 )    key = KEY_LEFTALT;
    else if ( strcmp(argv[1], "ralt") == 0 )    key = KEY_RIGHTALT;
    else if ( strcmp(argv[1], "lctrl") == 0 )   key = KEY_LEFTCTRL;
    else if ( strcmp(argv[1], "rctrl") == 0 )   key = KEY_RIGHTCTRL;

    // ls /dev/input/by-path/*-kbd
    FILE *kbd = fopen(argv[2], "r");

    res = ioctl(fileno(kbd), EVIOCGBIT(EV_KEY, bits_size), bits);
    bits_size = res + 16;
    bits = realloc(bits, bits_size * 2);
    
    memset(bits, 0, sizeof(bits));    //  Initate the array to zero's
    ioctl( fileno(kbd), EVIOCGKEY(res), bits);    //  Fill the keymap with the current keyboard state

    int keyb = bits[key/8];  //  The key we want (and the seven others arround it)
    int mask = 1 << (key % 8);  //  Put a one in the same column as out key state will be in;

    return !(keyb & mask);  //  Returns true if pressed otherwise false

}
