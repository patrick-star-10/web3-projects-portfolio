import { ConnectSection } from '@/components/ConnectSection';// 主页组件，展示连接钱包、读取/写入合约状态和事件列表
import { EventList } from '@/components/EventList'; // 事件列表组件，展示合约事件的实时变化
import { ReadContract } from '@/components/ReadContract'; // 读取合约组件，展示当前合约状态和数据
import { WriteContract } from '@/components/WriteContract';// 写入合约组件，提供交互界面让用户调用合约方法进行状态修改
import { CONTRACT_CHAIN } from '@/config/contracts';// 配置文件，包含合约所在的链信息，如链ID、名称等

export default function HomePage() {
  return (
    <main className="ui-shell flex min-h-screen flex-col gap-5">
      <header className="ui-card space-y-3">
        <p className="inline-flex w-fit rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-xs font-semibold tracking-wide text-emerald-700">
          {CONTRACT_CHAIN.name.toUpperCase()} NETWORK
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-slate-900 sm:text-4xl">
          Minimal DApp Control Panel
        </h1>
        <p className="max-w-2xl text-sm leading-6 text-slate-600 sm:text-base">
          一个简洁的链上交互面板，用来连接钱包、读取/写入合约状态，并实时查看事件变化。
        </p>
      </header>

      <ConnectSection />

      <section className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <ReadContract />
        <WriteContract />
      </section>

      <EventList />
    </main>
  );
}
