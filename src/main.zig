const r4os = @import("r4os");

pub fn r4_app_main(r4_app: *r4os.App) i32 {
    const ctx = r4_app.system();
    const dev = r4_app.devicesLowLevel() orelse return r4os.abi.err_no_group;
    var ok = true;

    ctx.println("DRVDIAG");
    const header_ok = ctx.contractValid() and dev.hasFn("performance_summary");
    printCheck(&ctx, "R4DEV driver workqueue snapshot v136", header_ok);
    ok = header_ok and ok;

    const summary = dev.performanceSummary() orelse {
        printCheck(&ctx, "driver performance snapshot", false);
        ctx.println("DRVDIAG result: FAILED");
        return 1;
    };

    ok = checkWorker(&ctx, summary) and ok;
    ok = checkDeferredWork(&ctx, summary) and ok;
    ok = checkCompletion(&ctx, summary) and ok;
    printBaseline(&ctx, summary);

    ctx.print("DRVDIAG result: ");
    ctx.println(if (ok) "OK" else "FAILED");
    return if (ok) 0 else 1;
}

fn checkWorker(ctx: *const r4os.r4sys.Context, summary: r4os.abi.ProgramPerformanceSummary) bool {
    const ok = (summary.flags & r4os.abi.performance_flag_driver_workqueue_ready) != 0 and
        summary.driver_work_worker_started != 0 and
        summary.driver_work_capacity >= r4os.abi.driver_work_queue_capacity;
    printCheck(ctx, "Driver workqueue worker", ok);
    return ok;
}

fn checkDeferredWork(ctx: *const r4os.r4sys.Context, summary: r4os.abi.ProgramPerformanceSummary) bool {
    // 0.56.31-Triage: Seit der Treiber-Auslagerung (0.56.12, Storage via
    // R4D) submittet im Normal-Boot niemand mehr IRQ-Workitems - die
    // Live-Erwartung "irq>0" stammt aus der built-in-Aera. Inaktiv und
    // fehlerfrei ist heute der Sollzustand; sobald Items laufen, gelten
    // die alten Bedingungen weiter.
    const idle_ok = summary.driver_work_submitted_from_irq == 0 and
        summary.driver_work_started == 0 and
        summary.driver_work_failed == 0 and
        summary.driver_work_dropped == 0;
    const active_ok = summary.driver_work_submitted_from_irq > 0 and
        summary.driver_work_submitted_from_task == 0 and
        summary.driver_work_started > 0 and
        summary.driver_work_completed > 0 and
        summary.driver_work_failed == 0 and
        summary.driver_work_dropped == 0;
    const ok = idle_ok or active_ok;
    printCheck(ctx, "Driver deferred work", ok);
    return ok;
}

fn checkCompletion(ctx: *const r4os.r4sys.Context, summary: r4os.abi.ProgramPerformanceSummary) bool {
    // 0.56.31-Triage: analog checkDeferredWork - keine Waits ist seit der
    // R4D-Auslagerung zulaessig, solange nichts fehlschlaegt.
    const idle_ok = summary.driver_work_waits == 0 and
        summary.driver_work_wait_timeouts == 0 and
        summary.driver_work_wait_denied_irq == 0 and
        summary.driver_work_invalid_handles == 0;
    const active_ok = summary.driver_work_waits > 0 and
        summary.driver_work_wait_timeouts == 0 and
        summary.driver_work_wait_denied_irq == 0 and
        summary.driver_work_releases > 0 and
        summary.driver_work_invalid_handles == 0;
    const ok = idle_ok or active_ok;
    printCheck(ctx, "Driver completion wait", ok);
    return ok;
}

fn printBaseline(ctx: *const r4os.r4sys.Context, summary: r4os.abi.ProgramPerformanceSummary) void {
    ctx.print("  Driver workqueue: cap=");
    ctx.printU64(summary.driver_work_capacity);
    ctx.print(" depth=");
    ctx.printU64(summary.driver_work_depth);
    ctx.print(" high=");
    ctx.printU64(summary.driver_work_high_water);
    ctx.print(" submitted=");
    ctx.printU64(summary.driver_work_submitted);
    ctx.print(" irq=");
    ctx.printU64(summary.driver_work_submitted_from_irq);
    ctx.print(" completed=");
    ctx.printU64(summary.driver_work_completed);
    ctx.print(" waits=");
    ctx.printU64(summary.driver_work_waits);
    ctx.print(" timeouts=");
    ctx.printU64(summary.driver_work_wait_timeouts);
    ctx.print(" dropped=");
    ctx.printU64(summary.driver_work_dropped);
    ctx.print(" qmax=");
    ctx.printU64(summary.driver_work_queue_max_ticks);
    ctx.print(" runmax=");
    ctx.printU64(summary.driver_work_run_max_ticks);
    ctx.print(" waitmax=");
    ctx.printU64(summary.driver_work_wait_max_ticks);
    ctx.println("");
}

fn printCheck(ctx: *const r4os.r4sys.Context, name: []const u8, ok: bool) void {
    ctx.write("  ");
    ctx.write(name);
    ctx.write(": ");
    ctx.println(if (ok) "OK" else "FAILED");
}
