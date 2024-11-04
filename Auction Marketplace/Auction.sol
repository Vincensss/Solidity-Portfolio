//SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.0;

contract AuctionCreator{
    Auction[] public auctions;

    function createAuction() public{
        Auction newAuction = new Auction(msg.sender);
        auctions.push(newAuction);
    }
}

contract Auction{                   //Asta
    address payable public owner;   //address proprietario
    uint public startBlock;         //inizio asta
    uint public endBlock;           // fine asta
    string public ipfsHash;         // codice hash per caricare immagini
    
    enum State {Started, Running, Ended, Canceled} //stato asta
    State public auctionState;

    uint public highestBindingBid;               //indirizzo che vince l'asta
    address payable public highestBidder;

    mapping(address => uint) public bids;
    uint bidIncrement;

    constructor(address eoa){
        owner = payable(eoa);
        auctionState = State.Running;
        startBlock = block.number;
        endBlock = startBlock + 3; //durata asta 40320 blocchi
        ipfsHash = "";
        bidIncrement = 1000000000000000000;    //100wei
    }

    modifier notOwner(){                    //condizione, il proprietario non puo chiamare le funzioni
        require(msg.sender != owner);
        _;
    }

    modifier afterStart(){                  //condizione, avviene dopo l'inizio del blocco
        require(block.number >= startBlock);
        _;
    }

    modifier beforeEnd(){                   //condizione, avviene prima della fine del blocco
        require(block.number <= endBlock);
        _;
    }

    modifier onlyOwner(){                   //condizione solo proprietario
        require(msg.sender == owner);
        _;
    }

    function cancelAuction() public onlyOwner{    //cfunzione che cancella asta
        auctionState = State.Canceled;
    }

    function min(uint a, uint b) pure internal returns(uint){
        if(a <= b){
            return a;
        }else{
            return b;
        }
    }

    function placeBid() public payable notOwner afterStart beforeEnd{    //funzione permette di fare offerte
        require(auctionState == State.Running);                          //requisito stato asta attivo
        require(msg.value >= 100);                                       //requisito offerta minima >= 100
        
        uint currentBid = bids[msg.sender] + msg.value;
        require(currentBid > highestBindingBid);

        bids[msg.sender] = currentBid;

        if(currentBid <= bids[highestBidder]){
            highestBindingBid = min(currentBid + bidIncrement, bids[highestBidder]);

        }else{
            highestBindingBid = min(currentBid, bids[highestBidder] + bidIncrement);
            highestBidder = payable(msg.sender);
        }

    }

    function finalizeAuction() public{
        require(auctionState == State.Canceled || block.number > endBlock);
        require(msg.sender == owner || bids[msg.sender] > 0);

        address payable recipient;
        uint value;

        if(auctionState == State.Canceled){          //asta cancellata
            recipient = payable(msg.sender);
            value = bids[msg.sender];
        }else{                                       //asta finita
            if(msg.sender == owner){                // proprietario
                recipient = owner;
                value = highestBindingBid;
            }else{                                   //questo è miglior l'offerente 
                if(msg.sender == highestBidder){
                    recipient = highestBidder;
                    value = bids[highestBidder] - highestBindingBid;
                }else{                               //uno degli offerenti qualsisasi
                    recipient = payable(msg.sender);
                    value = bids[msg.sender];
         
                
                }
            }
        }

        bids[recipient] = 0;         //azzeramento delle offerte del destinatario. Il rimborso puio essere chiesto una sola volta
        recipient.transfer(value);  //invia valore al destinatario 
    }

}