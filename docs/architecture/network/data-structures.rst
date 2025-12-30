=======================
Network Data Structures
=======================

.. contents:: Table of Contents
   :depth: 2
   :local:

Key Structures
--------------


From ``include/linux/socket.h``:

.. uml:: diagrams/class-socket.puml

* ``struct cmsghdr``
* ``struct linger``
* ``struct mmsghdr``
* ``struct msghdr``
* ``struct scm_timestamping_internal``
* ``struct sockaddr``
* ``struct sockaddr_unsized``
* ``struct ucred``
* ``struct user_msghdr``

From ``include/net/sock.h``:

.. uml:: diagrams/class-sock.puml

* ``struct __anonf0c9d8100108``
* ``struct __anonf0c9d8100308``
* ``struct __anonf0c9d8100608``
* ``struct __anonf0c9d8100c08``
* ``struct __anonf0c9d8101108``
* ``struct prot_inuse``
* ``struct proto``
* ``struct proto_accept_arg``
* ``struct sock``
* ``struct sock_bh_locked``
* ``struct sock_common``
* ``struct sock_skb_cb``
* ``struct sockcm_cookie``
* ``struct socket_alloc``

From ``include/linux/skbuff.h``:

.. uml:: diagrams/class-skbuff.puml

* ``struct __anonbf5f7bea0808``
* ``struct __anonbf5f7bea0908``
* ``struct __anonbf5f7bea0c08``
* ``struct __anonbf5f7bea1008``
* ``struct __anonbf5f7bea1408``
* ``struct mmpin``
* ``struct nf_bridge_info``
* ``struct sk_buff``
* ``struct sk_buff_fclones``
* ``struct sk_buff_head``
* ``struct skb_ext``
* ``struct skb_frag``
* ``struct skb_seq_state``
* ``struct skb_shared_hwtstamps``
* ``struct skb_shared_info``
* ``struct tc_skb_ext``
* ``struct ubuf_info``
* ``struct ubuf_info_msgzc``
* ``struct ubuf_info_ops``
* ``struct xsk_tx_metadata_compl``
