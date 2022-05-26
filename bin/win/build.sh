export ACME=/c/Users/Dave/Downloads/acme0.96.4win/acme/ACME_Lib 
export VICE=/c/Users/Dave/Downloads/GTK3VICE-3.3-win32/GTK3VICE-3.3-win32-r35872
bin/win/acme -f cbm -l build/labels -o build/lores.ml.prg code/lores.asm
[ $? -eq 0 ] || exit 1
[ $? -eq 0 ] && ${VICE}/c1541 << EOF
attach build/slides.d64
delete lores.ml
delete lores.asm
delete license
write build/lores.ml.prg lores.ml
write code/lores.asm lores.asm,s
write LICENSE license,s
EOF
[ $? -eq 0 ] && ${VICE}/x64.exe -moncommands build/labels build/slides.d64
