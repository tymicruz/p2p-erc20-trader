from doctest import master
from scripts.helpful_scripts import get_account
from brownie import config, network, P2pErc20Trader, interface


def deploy():
    account = get_account()
    p2p_erc20_trader = P2pErc20Trader.deploy({"from":account})
    
def main():
    deploy()
