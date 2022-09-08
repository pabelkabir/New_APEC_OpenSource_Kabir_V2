#!/bin/bash
#This script is to make xyz file for QM/MM calculation

template_path="/userapp/APEC_KABIR/New_APEC/template"

   echo ""
   echo "what is the name of pdb file (without .pdb)?"
   echo ""
   read file
if [[ -f $file.pdb ]]; then
   echo "$file.pdb will be used"
   echo ""
else
   echo ""
   echo " $file.pdb does not exist"
   echo ""
   exit 0
fi

cofactor=nothing
while [[ $cofactor != FMN && $cofactor != FAD ]]; do
   echo ""
   echo "what is the type of co-factor (FMN or FAD)?"
   echo ""
   read cofactor
done

chain=nothing
while [[ $chain != A && $chain != B ]]; do
   echo ""
   echo "What chain you would like to use? (A or B)"
   echo ""
   read chain
done

redox=20
while [[ $redox -ne 1 && $redox -ne 2 && $redox -ne 3 && $redox -ne 4 && $redox -ne 5 && $redox -ne 6 ]]; do
   echo ""
   echo "What is the redox state of co-factor?
         1. quinone
         2. semiquinone
         3. hydroquinone
         4. anionic quinone
         5. anionic semiquinone
         6. anionic hydroquinone"
   echo ""
   read redox
done

#backup for main file
cp $file.pdb $file.pdb_backup

#for chain A
if [[ $chain == A ]]; then

  grep -E "ATOM  |HETATM |TER    " "$file".pdb > "$file"_temp.pdb
  sed -i '/REMARK/d' "$file"_temp.pdb
  sed -i '/MASTER/d' "$file"_temp.pdb
  sed -i '/ B/d' "$file"_temp.pdb

#for chain B  
else
  egrep "ATOM  |HETATM |TER    " "$file".pdb | grep " B" > "$file"_temp.pdb
  sed -i '/REMARK/d' "$file"_temp.pdb
  sed -i '/MASTER/d' "$file"_temp.pdb
fi

#for FMN
if [[ $cofactor == FMN ]]; then

#adding hydrogen
#   module load openbabel
   grep "$cofactor" "$file"_temp.pdb | tail -n31 > temp.pdb
   /userapp/APEC_KABIR/New_APEC/bin/babel -ipdb -h temp.pdb -opdb babel.pdb
#separating xyz and connectivity
   grep "$cofactor" babel.pdb > $cofactor.xyz

#removing phosphate hydrogen
   sed -i '$d' $cofactor.xyz
   sed -i '$d' $cofactor.xyz
   sed -i 's/....................../& /' $cofactor.xyz

#adding hydrogen to nitrogen
cat > format.py << pabel
import shutil
a = 1 #input("Enter the first  referance atom number: ")
b = 5 #input("Enter the second  referance atom number: ")
m = 8 #input("Enter the first  referance atom number: ")
n = 17 #input("Enter the second  referance atom number: ")
c = 1 #input("Enter the unit distance: ")
f = open('FMN.xyz', 'r')
data = f.read()
f.close
shutil.copyfile('FMN.xyz', 'temp.xyz')
data = data.split()
x = data[6::12]
y = data[7::12]
z = data[8::12]
x = [float(i) for i in x]
y = [float(i) for i in y]
z = [float(i) for i in z]
d1=((x[a-1]-x[b-1])**2 + (y[a-1]-y[b-1])**2 + (z[a-1]-z[b-1])**2)**0.5 
d2=((x[m-1]-x[n-1])**2 + (y[m-1]-y[n-1])**2 + (z[m-1]-z[n-1])**2)**0.5 
p1 = x[a-1] + (x[a-1] - x[b-1])*c/d1
p2 = y[a-1] + (y[a-1] - y[b-1])*c/d1
p3 = z[a-1] + (z[a-1] - z[b-1])*c/d1
q1 = x[m-1] + (x[m-1] - x[n-1])*c/d2
q2 = y[m-1] + (y[m-1] - y[n-1])*c/d2
q3 = z[m-1] + (z[m-1] - z[n-1])*c/d2
f = open('temp.xyz', "a")
print >>f, ("ATOM     51  H   FMN A1001      " + "{0:2.3f} {1:7.3f} {2:7.3f}".format(p1,  p2,   p3) + "  1.00  0.00           H")
print >>f, ("ATOM     52  H   FMN A1001      " + "{0:2.3f} {1:7.3f} {2:7.3f}".format(q1,  q2,   q3) + "  1.00  0.00           H")
f.close()
pabel
python2.7 format.py

#removing extra hydrogen atom
   atom=`wc -l temp.xyz | awk '{print $1}'`

if [[ $atom -eq 52 ]]; then
   echo ""
   echo "babel have added right number of hydrogen" 
   echo ""
else
   echo ""
   echo "something is wrong with the babel..."
   echo "aborting..."
   echo ""
   exit 0
fi

#backup templete
cp $template_path/00templete .
cp 00templete 0templete

#for quinone and anionic semiquinone
if [[ $redox -eq 1 || $redox -eq 5 ]]; then
   sed -i '52d' temp.xyz
   sed -i '52d' 0templete
   sed -i '51d' temp.xyz
   sed -i '51d' 0templete
fi

#for semiquinone and anionic hydroquinone
if [[ $redox -eq 2 || $redox -eq 6 ]]; then
   sed -i '51d' temp.xyz
   sed -i '51d' 0templete
fi

#for quinone and anionic semiquinone
if [[ $redox -eq 4 ]]; then
   sed -i '52d' temp.xyz
   sed -i '52d' 0templete
   sed -i '51d' temp.xyz
   sed -i '51d' 0templete
   sed -i '32d' temp.xyz
   sed -i '32d' 0templete
fi

   grep "  H  " temp.xyz > temp
   nl temp | awk '{ print $4 $1}' > temp1
   awk '{ printf  " %7s %10s %10s\n", $7, $8, $9}' temp > temp2
   paste temp1 temp2 > hydrogen
   sed -i '/  H  /d' temp.xyz
   awk '{ printf "%-5s %10s %10s %10s\n", $3, $7, $8, $9}' temp.xyz > $cofactor.pdb1
   cat $cofactor.pdb1 hydrogen > $cofactor.pdb2
   paste $cofactor.pdb2 0templete > $cofactor.xyz
   echo "the extra hydrogen has been deleted"

#adding number of atom on the top
  wc -l $cofactor.xyz | awk '{print $1}' > temp3
  echo "" >> temp3
  cat temp3 $cofactor.xyz > ${file}_CHR.xyz

#processing connectivities
  grep 'CONECT' babel.pdb > temp4
  awk '{printf "%02d    %02d    %02d    %02d   %02d\n" , $2 , $3 , $4 , $5 ,$6}' temp4 > temp5
  awk '{printf "%02d   %02d\n" , $1 , $2}' temp5 > temp6
  awk '{printf "%02d   %02d\n" , $1 , $3}' temp5 > temp7
  awk '{printf "%02d   %02d\n" , $1 , $4}' temp5 > temp8
  awk '{printf "%02d   %02d\n" , $1 , $5}' temp5 > temp9
  cat temp6 temp7 temp8 temp9 > temp10

#for quinone, semiquinone, hydroquinone, anionic quinone, anionic semiquinone and anionic hydroquinone
if [[ $redox -eq 1 || $redox -eq 2 || $redox -eq 3 || $redox -eq 5 || $redox -eq 6 ]]; then
  sed -i '/00/d' temp10
  sed -i '/51/d' temp10
  sed -i '/52/d' temp10
  awk '!a[$1$2]++ && !a[$2$1]++' temp10 > temp11
  awk '{printf "%2d   %2d\n" , $1 , $2}' temp11 > text
fi

#for anionic quinone
if [[ $redox -eq 4 ]]; then
  sed -i '/00/d' temp10
  sed -i '/51/d' temp10
  sed -i '/52/d' temp10
  sed -i '/32/d' temp10
  awk '!a[$1$2]++ && !a[$2$1]++' temp10 > temp11
  awk '{printf "%2d   %2d\n" , $1 , $2}' temp11 > text
fi

if [ -f connectivities0 ]; then
   rm connectivities0
fi
#labelilg atom
#for quinone, semiquinone, hydroquinone, anionic quinone, anionic semiquinone and anionic hydroquinone
if [[ $redox -eq 1 || $redox -eq 2 || $redox -eq 3 || $redox -eq 5 || $redox -eq 6 ]]; then
  for i in {1..50}; do
     atom=`head -n $i $cofactor.xyz | tail -n1 | awk '{ print $1 }'`
     conv[$i]=$atom
  done
fi
#for anionic quinone
if [[ $redox -eq 4 ]]; then
  for i in {1..31}; do
     atom=`head -n $i $cofactor.xyz | tail -n1 | awk '{ print $1 }'`
     conv[$i]=$atom
  done
  for i in {33..50}; do
     atom=`head -n $(($i-1)) $cofactor.xyz | tail -n1 | awk '{ print $1 }'`
     conv[$i]=$atom
  done
fi
#for quinone and anionic semiquinone
if [[ $redox -eq 1 || $redox -eq 5 ]]; then
  for i in {1..52}; do
    atom1=`head -n $i text | tail -n1 | awk '{ print $1 }'`
    atom2=`head -n $i text | tail -n1 | awk '{ print $2 }'`
    echo "${conv[atom1]}    ${conv[atom2]}" >> connectivities0
  done
    awk '{ printf  "%-7s %-10s\n", $1, $2}' connectivities0 > connectivities
    echo "End" >> connectivities
    echo "" >> connectivities
fi

#for semiquinone and anionic hydroquinone
if [[ $redox -eq 2 || $redox -eq 6 ]]; then
  for i in {1..52}; do
    atom1=`head -n $i text | tail -n1 | awk '{ print $1 }'`
    atom2=`head -n $i text | tail -n1 | awk '{ print $2 }'`
    echo "${conv[atom1]}    ${conv[atom2]}" >> connectivities0
  done
    awk '{ printf  "%-7s %-10s\n", $1, $2}' connectivities0 > connectivities
    echo "H20     N5" >> connectivities
    echo "End" >> connectivities
    echo "" >> connectivities
fi

#for hydroquinone
if [[ $redox -eq 3 ]]; then
  for i in {1..52}; do
    atom1=`head -n $i text | tail -n1 | awk '{ print $1 }'`
    atom2=`head -n $i text | tail -n1 | awk '{ print $2 }'`
    echo "${conv[atom1]}    ${conv[atom2]}" >> connectivities0
  done
    awk '{ printf  "%-7s %-10s\n", $1, $2}' connectivities0 > connectivities
    echo "H20     N1" >> connectivities
    echo "H21     N5" >> connectivities
    echo "End" >> connectivities
    echo "" >> connectivities
fi
#for anionic quinone
if [[ $redox -eq 4 ]]; then
  for i in {1..51}; do
    atom1=`head -n $i text | tail -n1 | awk '{ print $1 }'`
    atom2=`head -n $i text | tail -n1 | awk '{ print $2 }'`
    echo "${conv[atom1]}    ${conv[atom2]}" >> connectivities0
  done
    awk '{ printf  "%-7s %-10s\n", $1, $2}' connectivities0 > connectivities
    echo "End" >> connectivities
    echo "" >> connectivities
fi

#combinning xyz with connectivities
cat ${file}_CHR.xyz connectivities > CHR_chain.xyz

sed "/$cofactor/d" "$file"_temp.pdb > "$file".pdb
rm temp* connectivities* FMN* babel* hydrogen text "$file"_* format.py 0templete

#for FAD
else

#adding hydrogen
#   module load openbabel
   grep "$cofactor" "$file"_temp.pdb | tail -n53 > temp.pdb
   /userapp/APEC_KABIR/New_APEC/bin/babel -ipdb -h temp.pdb -opdb babel.pdb
#separating xyz and connectivity
   grep "$cofactor" babel.pdb > $cofactor.xyz

#removing phosphate hydrogen
   sed -i '86d' $cofactor.xyz
   sed -i '54d' $cofactor.xyz
   sed -i 's/....................../& /' $cofactor.xyz

#adding hydrogen to nitrogen
cat > format.py << pabel
import shutil
a = 23 #input("Enter the first  referance atom number: ")
b = 27 #input("Enter the second  referance atom number: ")
m = 30 #input("Enter the first  referance atom number: ")
n = 39 #input("Enter the second  referance atom number: ")
c = 1 #input("Enter the unit distance: ")
f = open('FAD.xyz', 'r')
data = f.read()
f.close
shutil.copyfile('FAD.xyz', 'temp.xyz')
data = data.split()
x = data[6::12]
y = data[7::12]
z = data[8::12]
x = [float(i) for i in x]
y = [float(i) for i in y]
z = [float(i) for i in z]
d1=((x[a-1]-x[b-1])**2 + (y[a-1]-y[b-1])**2 + (z[a-1]-z[b-1])**2)**0.5 
d2=((x[m-1]-x[n-1])**2 + (y[m-1]-y[n-1])**2 + (z[m-1]-z[n-1])**2)**0.5 
p1 = x[a-1] + (x[a-1] - x[b-1])*c/d1
p2 = y[a-1] + (y[a-1] - y[b-1])*c/d1
p3 = z[a-1] + (z[a-1] - z[b-1])*c/d1
q1 = x[m-1] + (x[m-1] - x[n-1])*c/d2
q2 = y[m-1] + (y[m-1] - y[n-1])*c/d2
q3 = z[m-1] + (z[m-1] - z[n-1])*c/d2
f = open('temp.xyz', "a")
print >>f, ("ATOM     85  H   FAD A1001      " + "{0:2.3f} {1:7.3f} {2:7.3f}".format(p1,  p2,   p3) + "  1.00  0.00           H")
print >>f, ("ATOM     86  H   FAD A1001      " + "{0:2.3f} {1:7.3f} {2:7.3f}".format(q1,  q2,   q3) + "  1.00  0.00           H")
f.close()
pabel
python2.6 format.py

#removing extra hydrogen atom
   atom=`wc -l temp.xyz | awk '{print $1}'`

if [[ $atom -eq 86 ]]; then
   echo ""
   echo "babel have added right number of hydrogen" 
   echo ""
else
   echo ""
   echo "something is wrong with the babel..."
   echo "aborting..."
   echo ""
   exit 0
fi

#backup templete
cp 00templete 0templete

#for quinone and anionic semiquinone
if [[ $redox -eq 1 || $redox -eq 5 ]]; then
   sed -i '86d' temp.xyz
   sed -i '52d' 0templete
   sed -i '85d' temp.xyz
   sed -i '51d' 0templete
fi

#for semiquinone and anionic hydroquinone
if [[ $redox -eq 2 || $redox -eq 6 ]]; then
   sed -i '85d' temp.xyz
   sed -i '51d' 0templete
fi

#for anionic quinone
if [[ $redox -eq 4 ]]; then
   sed -i '86d' temp.xyz
   sed -i '52d' 0templete
   sed -i '85d' temp.xyz
   sed -i '51d' 0templete
   sed -i '66d' temp.xyz
   sed -i '32d' 0templete
fi

   grep "  H  " temp.xyz > temp
   nl temp | awk '{ print $4 $1}' > temp1
   awk '{ printf  " %7s %10s %10s\n", $6, $7, $8}' temp > temp2
   paste temp1 temp2 > hydrogen
   sed -i '/  H  /d' temp.xyz
   awk '{ printf "%-5s %10s %10s %10s\n", $3, $6, $7, $8}' temp.xyz > $cofactor.pdb1
   cat $cofactor.pdb1 hydrogen > $cofactor.pdb2
   paste $cofactor.pdb2 0templete > $cofactor.xyz
   echo "the extra hydrogen has been deleted"

#adding number of atom on the top
  wc -l $cofactor.xyz | awk '{print $1}' > temp3
  echo "" >> temp3
  cat temp3 $cofactor.xyz > ${file}_CHR.xyz

#processing connectivities
  grep 'CONECT' babel.pdb > temp4
  awk '{printf "%02d    %02d    %02d    %02d   %02d\n" , $2 , $3 , $4 , $5 ,$6}' temp4 > temp5
  awk '{printf "%02d   %02d\n" , $1 , $2}' temp5 > temp6
  awk '{printf "%02d   %02d\n" , $1 , $3}' temp5 > temp7
  awk '{printf "%02d   %02d\n" , $1 , $4}' temp5 > temp8
  awk '{printf "%02d   %02d\n" , $1 , $5}' temp5 > temp9
  cat temp6 temp7 temp8 temp9 > temp10

#for quinone, semiquinone, hydroquinone, anionic quinone, anionic semiquinone and anionic hydroquinone
if [[ $redox -eq 1 || $redox -eq 2 || $redox -eq 3 || $redox -eq 5 || $redox -eq 6 ]]; then
  sed -i '/00/d' temp10
  sed -i '/54/d' temp10
  sed -i '/86/d' temp10
  awk '!a[$1$2]++ && !a[$2$1]++' temp10 > temp11
  awk '{printf "%2d   %2d\n" , $1 , $2}' temp11 > text
fi

#for anionic quinone
if [[ $redox -eq 4 ]]; then
  sed -i '/00/d' temp10
  sed -i '/54/d' temp10
  sed -i '/86/d' temp10
  sed -i '/67/d' temp10
  awk '!a[$1$2]++ && !a[$2$1]++' temp10 > temp11
  awk '{printf "%2d   %2d\n" , $1 , $2}' temp11 > text
fi

if [ -f connectivities0 ]; then
   rm connectivities0
fi
#labelilg atom
#for quinone, semiquinone, hydroquinone, anionic quinone, anionic semiquinone and anionic hydroquinone
if [[ $redox -eq 1 || $redox -eq 2 || $redox -eq 3 || $redox -eq 5 || $redox -eq 6 ]]; then
  for i in {1..53}; do
     atom=`head -n $i $cofactor.xyz | tail -n1 | awk '{ print $1 }'`
     conv[$i]=$atom
  done
  for i in {55..85}; do
     atom=`head -n $(($i-1)) $cofactor.xyz | tail -n1 | awk '{ print $1 }'`
     conv[$i]=$atom
  done
fi
#for anionic quinone
if [[ $redox -eq 4 ]]; then
  for i in {1..53}; do
     atom=`head -n $i $cofactor.xyz | tail -n1 | awk '{ print $1 }'`
     conv[$i]=$atom
  done
  for i in {55..66}; do
     atom=`head -n $(($i-1)) $cofactor.xyz | tail -n1 | awk '{ print $1 }'`
     conv[$i]=$atom
  done
  for i in {68..85}; do
     atom=`head -n $(($i-2)) $cofactor.xyz | tail -n1 | awk '{ print $1 }'`
     conv[$i]=$atom
  done
fi

#for quinone and anionic semiquinone
if [[ $redox -eq 1 || $redox -eq 5 ]]; then
  for i in {1..89}; do
    atom1=`head -n $i text | tail -n1 | awk '{ print $1 }'`
    atom2=`head -n $i text | tail -n1 | awk '{ print $2 }'`
    echo "${conv[atom1]}    ${conv[atom2]}" >> connectivities0
  done
    awk '{ printf  "%-7s %-10s\n", $1, $2}' connectivities0 > connectivities
    echo "End" >> connectivities
    echo "" >> connectivities
fi

#for semiquinone and anionic hydroquinone
if [[ $redox -eq 2 || $redox -eq 6 ]]; then
  for i in {1..89}; do
    atom1=`head -n $i text | tail -n1 | awk '{ print $1 }'`
    atom2=`head -n $i text | tail -n1 | awk '{ print $2 }'`
    echo "${conv[atom1]}    ${conv[atom2]}" >> connectivities0
  done
    awk '{ printf  "%-7s %-10s\n", $1, $2}' connectivities0 > connectivities
    echo "H32     N5" >> connectivities
    echo "End" >> connectivities
    echo "" >> connectivities
fi

#for hydroquinone
if [[ $redox -eq 3 ]]; then
  for i in {1..89}; do
    atom1=`head -n $i text | tail -n1 | awk '{ print $1 }'`
    atom2=`head -n $i text | tail -n1 | awk '{ print $2 }'`
    echo "${conv[atom1]}    ${conv[atom2]}" >> connectivities0
  done
    awk '{ printf  "%-7s %-10s\n", $1, $2}' connectivities0 > connectivities
    echo "H32     N1" >> connectivities
    echo "H33     N5" >> connectivities
    echo "End" >> connectivities
    echo "" >> connectivities
fi
#for anionic quinone
if [[ $redox -eq 4 ]]; then
  for i in {1..88}; do
    atom1=`head -n $i text | tail -n1 | awk '{ print $1 }'`
    atom2=`head -n $i text | tail -n1 | awk '{ print $2 }'`
    echo "${conv[atom1]}    ${conv[atom2]}" >> connectivities0
  done
    awk '{ printf  "%-7s %-10s\n", $1, $2}' connectivities0 > connectivities
    echo "End" >> connectivities
    echo "" >> connectivities
fi

#combinning xyz with connectivities
cat ${file}_CHR.xyz connectivities > CHR_chain.xyz

sed "/$cofactor/d" "$file"_temp.pdb > "$file".pdb
rm temp* connectivities* FAD* babel* hydrogen text "$file"_* format.py 0templete

fi

cp $template_path/New_APEC_1.sh .
./New_APEC_1.sh
rm 00templete
