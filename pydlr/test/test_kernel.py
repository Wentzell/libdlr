
""" Author: Hugo U.R. Strand (2021) """


import numpy as np

from pydlr import dlr, kernel

def test_kernel(verbose=False):

    d = dlr(lamb=100.)
    d.tt = d.t.copy()
    d.tt += (d.t[::-1] > 0) * (1 - d.t[::-1])

    kmat = kernel(d.tt, d.om)

    np.testing.assert_array_almost_equal(kmat, d.kmat)

    if verbose:
        import matplotlib.pyplot as plt

        plt.figure(figsize=(6, 8))

        subp = [3, 1, 1]

        plt.subplot(*subp); subp[-1] += 1
        plt.title(r'Kernel $K_\Lambda(\tau, \omega)$, $\Lambda = %3.1f$, $\epsilon = %2.2E$' % (d.lamb, d.eps))
        plt.pcolormesh(d.tt, d.om, d.kmat.T, shading='nearest')
        plt.xlabel(r'$\tau$')
        plt.ylabel(r'$\omega$')

        plt.subplot(*subp); subp[-1] += 1
        plt.title(r'$N_{dlr} = %i$' % d.rank)
        plt.plot(d.tt, 0*d.tt, '.-')
        plt.plot(0*d.om, d.om, '.-')
        plt.plot(d.tt[d.tidx - 1], 0*d.tt[d.tidx - 1], 'x', label=r'$\tau_i$ (DLR)')
        plt.plot(0.*d.om[d.oidx - 1], d.om[d.oidx - 1], 'x', label=r'$\omega_j$ (DLR)')
        plt.xlabel(r'$\tau$')
        plt.ylabel(r'$\omega$')
        plt.legend(loc='best')

        plt.subplot(*subp); subp[-1] += 1
        plt.plot(d.dlrmf, 0*d.dlrmf, 'o', label=r'$i\omega_n$ (DLR) subset')
        plt.xlabel(r'$i \omega_n$')
        plt.legend(loc='best')

        plt.tight_layout()
        plt.show()


if __name__ == '__main__':

    test_kernel(verbose=True)
