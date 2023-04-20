

class RxGearboxModel:
    def __init__(self, type='int'):
        if type == 'str':
            self.obuf = ['XXX' for _ in range(67)] # Extra bit for half slip
        else:
            self.obuf = [0 for _ in range(67)]
        self.cycle = 0
        self.half_slip = 0


    def next(self, idata, slip=False):

        self.slip = slip
        self.count = int(self.cycle % 33)
        self.valid = self.count != 0
        self.frame_word = int(self.count % 2 == 0)
        self.output_header = int(self.count % 2 == 1)

        data_idxs = [00,32,64,30,62,28,60,26,58,24,56,22,54,20,52,18,50,16,48,14,46,12,44,10,42,8,40,6,38,4,36,2,34]

        # if self.count % 2 == 0:
        #     idata_idx = (66 - self.count) % 66
        #     obuf[idata_idx:66] = idata[0 : self.count]
        #     obuf[0:32-self.count] = idata[self.count:]

        # else:
        #     idata_idx = ((66 - self.count - 32) - 1) % 66
        #     obuf[idata_idx : self.idata_idx + 32] = idata

        # bit select method

        for bit in range(len(self.obuf)):

            self.idata_idx = data_idxs[self.count]

            if self.count % 2 == 0:
                if self.idata_idx != 0 and bit >= self.idata_idx and bit < 66:
                    self.obuf[bit] = idata[bit-self.idata_idx]
                elif bit < 32 - self.count:
                    self.obuf[bit] = idata[self.count + bit]
            else:
                if bit >= self.idata_idx and bit < self.idata_idx + 32:
                    self.obuf[bit] = idata[bit - self.idata_idx]
    
        self.obuf[66] = self.obuf[0]

        if self.half_slip % 2 == 0:
            self.odata = self.obuf[2 : 34] if self.frame_word == 0 else self.obuf[34:66]
            self.oheader = self.obuf[0:2]
        else:
            self.odata = self.obuf[3 : 35] if self.frame_word == 0 else self.obuf[35:67]
            self.oheader = self.obuf[1:3]

        ret = {
            'data' : self.odata,
            'header' : self.oheader,
            'data_valid' : self.valid,
            'header_valid' : self.output_header,
            'obuf' : self.obuf,
            'cycle' : self.cycle
        }

        if not self.slip:
            self.cycle = self.cycle + 1

        if slip:
            self.half_slip = self.half_slip + 1

        return ret

        


    def get_state(self):

        return f'{self.count:03d}\t{self.slip:b}\t{self.valid}\t{int(self.output_header)}\t{self.idata_idx:02d}\t{self.oheader}\t{self.odata}'
