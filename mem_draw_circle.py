f=open("MEM_dump.txt","r")
f1=open("MEM_draw.txt","w")
mem=[]
mem_draw=[]
for i in range (512):
    mem.append(f.readline()[0:-1])
for i in range (int(512/2)):
    mem_draw.append(str(mem[2*i+1])+str(mem[2*i]))
    f1.write(mem_draw[i])
    f1.write("\n")
f.close()
f1.close()
